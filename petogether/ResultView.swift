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
    let originalImage: UIImage?
    let aiResult: String
    let sceneCategory: String
    let sceneSubcategory: String
    
    @State private var isSaved = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Original Photo Display
                if let image = originalImage {
                    VStack(alignment: .leading) {
                        Text("Original Photo")
                            .font(.headline)
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(10)
                    }
                }
                
                // AI Analysis Result Display
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Analysis Result")
                        .font(.headline)
                    
                    Text(aiResult)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Scene Information
                HStack {
                    VStack(alignment: .leading) {
                        Text("Scene Category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(sceneCategory)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Subcategory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(sceneSubcategory)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Action Buttons
                HStack {
                    Button(action: saveResult) {
                        HStack {
                            Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                            Text(isSaved ? "Saved" : "Save to App")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isSaved)
                    
                    Button(action: saveToPhotoLibrary) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Save to Album")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
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
        .navigationTitle("Analysis Result")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveResult() {
        // Save photo to app sandbox using PhotoManager
        if let image = originalImage {
            PhotoManager.shared.savePhotoToDocuments(image: image) { result in
                switch result {
                case .success(let filePath):
                    // Create PhotoRecord and save to database
                    let photoRecord = PhotoRecord(
                        imageUrl: filePath.absoluteString,
                        sceneCategory: sceneCategory,
                        sceneSubcategory: sceneSubcategory,
                        aiAnalysisResult: aiResult,
                        timestamp: Date()
                    )
                    
                    modelContext.insert(photoRecord)
                    isSaved = true
                    showAlert = true
                    alertMessage = "Photo saved to App"
                    print("Result saved to: \(filePath)")
                case .failure(let error):
                    showAlert = true
                    alertMessage = "Save failed: \(error.localizedDescription)"
                    print("Failed to save photo: \(error)")
                }
            }
        }
    }
    
    private func saveToPhotoLibrary() {
        // Save photo to system album
        if let image = originalImage {
            PhotoManager.shared.savePhotoToPhotoLibrary(image: image) { result in
                switch result {
                case .success:
                    showAlert = true
                    alertMessage = "Photo saved to system album"
                case .failure(let error):
                    showAlert = true
                    alertMessage = "Save failed: \(error.localizedDescription)"
                    print("Failed to save to album: \(error)")
                }
            }
        }
    }
    
    private func shareResult() {
        // Implement sharing logic
        if let image = originalImage {
            let items: [Any] = [image, "Photo analyzed by PetTogether AI"]
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
}

#Preview {
    ResultView(
        originalImage: nil,
        aiResult: "This is a photo taken in the park, featuring a cute little dog running on the grass. The background has blue sky and white clouds, making it perfect for a warm memory album.",
        sceneCategory: "Daily Life",
        sceneSubcategory: "Outdoor Activities"
    )
}