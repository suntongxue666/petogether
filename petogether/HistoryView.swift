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
            Group {
                if photoRecords.isEmpty {
                    // 显示空状态
                    VStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No history yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Your generated photos will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 显示历史记录列表
                    List {
                        ForEach(photoRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                            PhotoRecordRow(record: record)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.gray.opacity(0.05))
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            let record = photoRecords.sorted(by: { $0.timestamp > $1.timestamp })[index]
            // 使用PhotoManager删除照片文件
            if let imageURL = PhotoManager.shared.getFullURLForFileName(record.imageUrl) {
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
        HStack(spacing: 12) {
            // Left section with thumbnails and info
            VStack(alignment: .leading, spacing: 4) {
                // Two small thumbnails (64x64) with a plus sign between them
                HStack(spacing: 4) {
                    // Owner thumbnail
                    if let ownerImageUrl = record.ownerImageUrl,
                       let imageURL = PhotoManager.shared.getFullURLForFileName(ownerImageUrl),
                       FileManager.default.fileExists(atPath: imageURL.path),
                       let image = UIImage(contentsOfFile: imageURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipped()
                            .cornerRadius(4)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .cornerRadius(4)
                    }
                    
                    // Plus sign
                    Text("➕")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Pet thumbnail
                    if let petImageUrl = record.petImageUrl,
                       let imageURL = PhotoManager.shared.getFullURLForFileName(petImageUrl),
                       FileManager.default.fileExists(atPath: imageURL.path),
                       let image = UIImage(contentsOfFile: imageURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipped()
                            .cornerRadius(4)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .cornerRadius(4)
                    }
                }
                
                // Creation Time with required format
                Text(formatDate(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                // Scene Category
                Text(record.sceneCategory)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            HStack(alignment: .center, spacing: 12) {
                // Arrow indicator
                Text("→")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // AI Generated Image (longest side 96)
                if let imageURL = PhotoManager.shared.getFullURLForFileName(record.imageUrl),
                   FileManager.default.fileExists(atPath: imageURL.path),
                   let image = UIImage(contentsOfFile: imageURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 96) // Maintain 2:3 aspect ratio with longest side 96
                        .clipped()
                        .cornerRadius(4)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 64, height: 96)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.05)) // 与My页面相同的背景色
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}



#Preview {
    HistoryView()
}