//
//  PhotoManager.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import Foundation
import UIKit
import Photos

/// 照片管理服务类
class PhotoManager {
    static let shared = PhotoManager()
    
    private init() {}
    
    /// 保存照片到应用沙盒目录
    /// - Parameters:
    ///   - image: 要保存的UIImage对象
    ///   - completion: 保存完成后的回调，返回保存的文件URL和可能的错误
    func savePhotoToDocuments(image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        // 生成唯一文件名
        let fileName = "\(UUID().uuidString).jpg"
        
        // 获取Documents目录路径
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(.failure(PhotoManagerError.documentsDirectoryNotFound))
            return
        }
        
        // 构建完整文件路径
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        // 将UIImage转换为JPEG数据
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(PhotoManagerError.imageConversionFailed))
            return
        }
        
        // 保存到文件系统
        do {
            try imageData.write(to: filePath)
            completion(.success(filePath))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 保存照片到应用沙盒目录，返回文件名
    /// - Parameters:
    ///   - image: 要保存的UIImage对象
    ///   - completion: 保存完成后的回调，返回保存的文件名和可能的错误
    func savePhotoToDocumentsWithFileName(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 生成唯一文件名
        let fileName = "\(UUID().uuidString).jpg"
        
        // 获取Documents目录路径
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(.failure(PhotoManagerError.documentsDirectoryNotFound))
            return
        }
        
        // 构建完整文件路径
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        // 将UIImage转换为JPEG数据
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(PhotoManagerError.imageConversionFailed))
            return
        }
        
        // 保存到文件系统
        do {
            try imageData.write(to: filePath)
            completion(.success(fileName)) // 只返回文件名而不是完整路径
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 保存照片到系统相册
    /// - Parameters:
    ///   - image: 要保存的UIImage对象
    ///   - completion: 保存完成后的回调，返回可能的错误
    func savePhotoToPhotoLibrary(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        // 检查相册权限
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            // 已授权，直接保存
            saveImageToLibrary(image: image, completion: completion)
        case .notDetermined:
            // 请求权限
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.saveImageToLibrary(image: image, completion: completion)
                    } else {
                        completion(.failure(PhotoManagerError.photoLibraryAccessDenied))
                    }
                }
            }
        default:
            // 其他情况（受限、拒绝等）
            completion(.failure(PhotoManagerError.photoLibraryAccessDenied))
        }
    }
    
    /// 从文件路径加载照片
    /// - Parameter url: 照片文件的URL
    /// - Returns: UIImage对象，如果加载失败返回nil
    func loadPhoto(from url: URL) -> UIImage? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("照片文件不存在: \(url.path)")
            return nil
        }
        
        return UIImage(contentsOfFile: url.path)
    }
    
    /// 删除照片文件
    /// - Parameter url: 要删除的照片文件URL
    /// - Returns: 删除操作的结果
    func deletePhoto(at url: URL) -> Result<Void, Error> {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("照片文件已删除: \(url.path)")
                return .success(())
            } else {
                return .failure(PhotoManagerError.fileNotFound)
            }
        } catch {
            print("删除照片文件失败: \(error)")
            return .failure(error)
        }
    }
    
    /// 获取照片文件大小
    /// - Parameter url: 照片文件的URL
    /// - Returns: 文件大小（字节），如果获取失败返回nil
    func getPhotoFileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("获取文件大小失败: \(error)")
            return nil
        }
    }
    
    /// 获取照片文件修改时间
    /// - Parameter url: 照片文件的URL
    /// - Returns: 修改时间，如果获取失败返回nil
    func getPhotoModificationDate(at url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            print("获取文件修改时间失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 私有方法
    
    /// 实际保存图片到系统相册的操作
    private func saveImageToLibrary(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(PhotoManagerError.unknownError))
                }
            }
        }
    }
}

// MARK: - 错误类型定义

enum PhotoManagerError: Error, LocalizedError {
    case documentsDirectoryNotFound
    case imageConversionFailed
    case photoLibraryAccessDenied
    case fileNotFound
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "无法访问Documents目录"
        case .imageConversionFailed:
            return "图片转换失败"
        case .photoLibraryAccessDenied:
            return "相册访问权限被拒绝"
        case .fileNotFound:
            return "文件不存在"
        case .unknownError:
            return "未知错误"
        }
    }
}

extension PhotoManager {
    /// 根据文件名获取完整的文件路径URL
    /// - Parameter fileName: 文件名
    /// - Returns: 完整的文件路径URL，如果获取失败返回nil
    func getFullURLForFileName(_ fileName: String) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsPath.appendingPathComponent(fileName)
    }
}