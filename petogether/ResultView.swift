//
//  ResultView.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import SwiftUI
import UIKit
import SwiftData

struct ResultView: View {
    @Binding var originalImage: UIImage?
    let aiResult: String
    let sceneCategory: String
    let sceneSubcategory: String
    let ownerImage: UIImage?  // 主人照片
    let petImage: UIImage?    // 宠物照片
    let generationProgress: Int?  // AI图片生成进度百分比
    
    @State private var isSaved = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Generated Photo Display - Full width
                if let image = originalImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                } else {
                    // Pre-loading placeholder with gray background and My-icon120 image
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3/4, contentMode: .fit) // Use same aspect ratio as typical AI generated images
                            .cornerRadius(10)
                        
                        Image("My-icon120")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(20) // Add corner radius
                            .grayscale(1.0) // Change to grayscale mode
                        
                        // Progress percentage text
                        VStack {
                            Spacer()
                                .frame(height: 80) // Move down by 80 pixels
                            Text("Generating... \(generationProgress ?? 0)%")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(8)
                            Spacer()
                        }
                    }
                    .onAppear {
                        // Simulate progress updates
                        updateProgress()
                    }
                }
                
                // Action Buttons
                HStack {
                    Button(action: saveToPhotoLibrary) {
                        HStack {
                            Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                            Text(isSaved ? "Saved" : "Save")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSaved)
                    
                    Button(action: shareResult) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AI Generate photo")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveToPhotoLibrary() {
        // Save photo to system album
        if let image = originalImage {
            PhotoManager.shared.savePhotoToPhotoLibrary(image: image) { result in
                switch result {
                case .success:
                    isSaved = true
                    showAlert = true
                    alertMessage = "Photo saved to system album"
                    // Only save to system album, not to app database for history
                case .failure(let error):
                    showAlert = true
                    alertMessage = "Save failed: \(error.localizedDescription)"
                    print("Failed to save to album: \(error)")
                }
            }
        }
    }
    
    private func saveToDatabase() {
        // Save AI generated photo to app database for history
        if let image = originalImage {
            PhotoManager.shared.savePhotoToDocumentsWithFileName(image: image) { result in
                switch result {
                case .success(let aiImageFileName):
                    // Save owner image
                    if let ownerImage = self.ownerImage {
                        PhotoManager.shared.savePhotoToDocumentsWithFileName(image: ownerImage) { ownerResult in
                            let ownerImageFileName: String? = try? ownerResult.get()
                            
                            // Save pet image
                            if let petImage = self.petImage {
                                PhotoManager.shared.savePhotoToDocumentsWithFileName(image: petImage) { petResult in
                                    let petImageFileName: String? = try? petResult.get()
                                    
                                    // Create PhotoRecord and save to database
                                    let photoRecord = PhotoRecord(
                                        imageUrl: aiImageFileName,  // 只存储文件名而不是完整路径
                                        ownerImageUrl: ownerImageFileName,
                                        petImageUrl: petImageFileName,
                                        sceneCategory: self.sceneCategory,
                                        sceneSubcategory: self.sceneSubcategory,
                                        aiAnalysisResult: self.aiResult,
                                        timestamp: Date()
                                    )
                                    
                                    self.modelContext.insert(photoRecord)
                                    print("Photo saved to database: \(aiImageFileName)")
                                }
                            } else {
                                // Create PhotoRecord without pet image
                                let photoRecord = PhotoRecord(
                                    imageUrl: aiImageFileName,  // 只存储文件名而不是完整路径
                                    ownerImageUrl: ownerImageFileName,
                                    sceneCategory: self.sceneCategory,
                                    sceneSubcategory: self.sceneSubcategory,
                                    aiAnalysisResult: self.aiResult,
                                    timestamp: Date()
                                )
                                
                                self.modelContext.insert(photoRecord)
                                print("Photo saved to database: \(aiImageFileName)")
                            }
                        }
                    } else {
                        // Create PhotoRecord without owner image
                        let photoRecord = PhotoRecord(
                            imageUrl: aiImageFileName,  // 只存储文件名而不是完整路径
                            sceneCategory: self.sceneCategory,
                            sceneSubcategory: self.sceneSubcategory,
                            aiAnalysisResult: self.aiResult,
                            timestamp: Date()
                        )
                        
                        self.modelContext.insert(photoRecord)
                        print("Photo saved to database: \(aiImageFileName)")
                    }
                case .failure(let error):
                    print("Failed to save photo to database: \(error)")
                }
            }
        }
    }
    
    private func shareResult() {
        // Implement sharing logic
        if let image = originalImage {
            let items: [Any] = [image, "Love this amazing moment with my pet, created by Petogether AI https://apps.apple.com/app/id6754391749"]
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            
            // Get current UIWindowScene
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            // Get current UIWindow
            guard let window = scene.windows.first else { return }
            
            // Get current UIViewController
            if let rootVC = window.rootViewController {
                // Find the currently displayed view controller
                var currentVC = rootVC
                while let presentedVC = currentVC.presentedViewController {
                    currentVC = presentedVC
                }
                
                // Present the sharing interface
                currentVC.present(activityVC, animated: true)
            }
        }
    }
    
    private func updateProgress() {
        // If no progress is provided, simulate progress updates from 20% to 95%
        // In a real implementation, this would be updated by the AI service
        if generationProgress == nil {
            var currentProgress = 20
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
                if currentProgress < 95 {
                    currentProgress += 5
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

#Preview {
    ResultView(
        originalImage: .constant(nil),
        aiResult: "This is a photo taken in the park, featuring a cute little dog running on the grass. The background has blue sky and white clouds, making it perfect for a warm memory album.",
        sceneCategory: "Daily Life",
        sceneSubcategory: "Outdoor Activities",
        ownerImage: nil,
        petImage: nil,
        generationProgress: 50
    )
}