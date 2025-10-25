//
//  HistoryView.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var photoRecords: [PhotoRecord]
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            List {
                ForEach(photoRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                    NavigationLink(destination: PhotoDetailView(record: record)) {
                        PhotoRecordRow(record: record)
                    }
                }
                .onDelete(perform: deleteRecords)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            let record = photoRecords.sorted(by: { $0.timestamp > $1.timestamp })[index]
            // 使用PhotoManager删除照片文件
            if let imageURL = URL(string: record.imageUrl) {
                _ = PhotoManager.shared.deletePhoto(at: imageURL)
            }
            // 从数据库删除记录
            modelContext.delete(record)
        }
    }
}

// Photo Record Row View
struct PhotoRecordRow: View {
    let record: PhotoRecord
    
    var body: some View {
        HStack {
            // Thumbnail
            if let imageURL = URL(string: record.imageUrl),
               FileManager.default.fileExists(atPath: imageURL.path),
               let image = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Scene Information
                HStack {
                    Text(record.sceneCategory)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(record.sceneSubcategory)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Creation Time
                Text(formatDate(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // AI Analysis Preview
                if let analysis = record.aiAnalysisResult, !analysis.isEmpty {
                    Text(analysis)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Photo Detail View
struct PhotoDetailView: View {
    let record: PhotoRecord
    @State private var image: UIImage?
    @State private var imageSize: String = ""
    @State private var modificationDate: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Full-size Photo Display
                if let loadedImage = image {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .cornerRadius(10)
                        .overlay(
                            Text("Failed to load photo")
                                .foregroundColor(.secondary)
                        )
                }
                
                // Photo Information
                if !imageSize.isEmpty || !modificationDate.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo Information")
                            .font(.headline)
                        
                        if !imageSize.isEmpty {
                            HStack {
                                Text("File Size")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(imageSize)
                                    .font(.subheadline)
                            }
                        }
                        
                        if !modificationDate.isEmpty {
                            HStack {
                                Text("Modified Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(modificationDate)
                                    .font(.subheadline)
                            }
                        }
                    }
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
                        Text(record.sceneCategory)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Subcategory")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(record.sceneSubcategory)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Creation Time
                HStack {
                    Text("Creation Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(record.timestamp))
                        .font(.body)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // AI Analysis Result
                if let analysis = record.aiAnalysisResult, !analysis.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Analysis Result")
                            .font(.headline)
                        
                        Text(analysis)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Action Buttons
                HStack {
                    Button(action: saveToPhotoLibrary) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save to Album")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: sharePhoto) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Photo")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Load photo using PhotoManager
        if let imageURL = URL(string: record.imageUrl) {
            image = PhotoManager.shared.loadPhoto(from: imageURL)
            
            // Get file information
            if let fileSize = PhotoManager.shared.getPhotoFileSize(at: imageURL) {
                let sizeInKB = Double(fileSize) / 1024.0
                if sizeInKB >= 1024 {
                    imageSize = String(format: "%.1f MB", sizeInKB / 1024.0)
                } else {
                    imageSize = String(format: "%.1f KB", sizeInKB)
                }
            }
            
            if let modDate = PhotoManager.shared.getPhotoModificationDate(at: imageURL) {
                modificationDate = formatDate(modDate)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveToPhotoLibrary() {
        if let imageToSave = image {
            PhotoManager.shared.savePhotoToPhotoLibrary(image: imageToSave) { result in
                switch result {
                case .success:
                    // Can add success message here
                    print("Photo saved to system album")
                case .failure(let error):
                    print("Failed to save to album: \(error)")
                }
            }
        }
    }
    
    private func sharePhoto() {
        if let imageToShare = image {
            let items: [Any] = [imageToShare, "Photo analyzed by PetTogether AI"]
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
    HistoryView()
}