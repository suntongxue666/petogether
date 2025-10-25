//
//  PhotoPermissionManager.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import Foundation
import Photos
import Combine

class PhotoPermissionManager: ObservableObject {
    static let shared = PhotoPermissionManager()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus()
    }
    
    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    completion(status)
                }
            }
        } else {
            completion(authorizationStatus)
        }
    }
    
    var authorizationText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "需要访问您的相册来选择照片"
        case .restricted:
            return "访问相册受限，请检查设置"
        case .denied:
            return "访问相册被拒绝，请在设置中允许访问相册"
        case .authorized:
            return "已获得相册访问权限"
        case .limited:
            return "已获得相册有限访问权限"
        @unknown default:
            return "未知的相册访问状态"
        }
    }
}