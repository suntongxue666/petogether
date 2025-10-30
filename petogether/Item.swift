//
//  Item.swift
//  petogether
//
//  Created by Sun1 on 2025/10/23.
//

import Foundation
import SwiftData

// 照片记录数据模型
@Model
final class PhotoRecord {
    var id: UUID
    var imageUrl: String  // AI生成照片存储路径
    var ownerImageUrl: String?  // 主人照片存储路径
    var petImageUrl: String?  // 宠物照片存储路径
    var sceneCategory: String  // 场景分类
    var sceneSubcategory: String  // 场景子分类
    var aiAnalysisResult: String?  // AI分析结果
    var timestamp: Date
    
    init(id: UUID = UUID(), imageUrl: String, ownerImageUrl: String? = nil, petImageUrl: String? = nil, sceneCategory: String, sceneSubcategory: String, aiAnalysisResult: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.imageUrl = imageUrl
        self.ownerImageUrl = ownerImageUrl
        self.petImageUrl = petImageUrl
        self.sceneCategory = sceneCategory
        self.sceneSubcategory = sceneSubcategory
        self.aiAnalysisResult = aiAnalysisResult
        self.timestamp = timestamp
    }
}

// 场景分类数据模型
@Model
final class SceneCategory {
    var id: UUID
    var name: String  // 分类名称
    var subcategories: [SceneSubcategory]  // 子分类列表
    
    init(id: UUID = UUID(), name: String, subcategories: [SceneSubcategory] = []) {
        self.id = id
        self.name = name
        self.subcategories = subcategories
    }
}

// 场景子分类数据模型
@Model
final class SceneSubcategory {
    var id: UUID
    var name: String  // 子分类名称
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
