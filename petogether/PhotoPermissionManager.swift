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
            return "Need to access your photo library to select photos"
        case .restricted:
            return "Access to photo library is restricted, please check settings"
        case .denied:
            return "Access to photo library is denied, please allow access in settings"
        case .authorized:
            return "Photo library access granted"
        case .limited:
            return "Limited photo library access granted"
        @unknown default:
            return "Unknown photo library access status"
        }
    }
}