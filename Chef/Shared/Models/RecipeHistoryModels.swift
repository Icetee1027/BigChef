//
//  RecipeHistoryModels.swift
//  ChefHelper
//
//  本地儲存的歷史記錄模型
//

import Foundation

// MARK: - 食譜歷史記錄
struct RecipeHistory: Codable, Identifiable {
    let id: String                          // UUID
    let timestamp: Date                     // 建立時間
    let requestHash: String                 // 請求的 hash 值，用於快取查找
    
    // 請求資料
    let request: SuggestRecipeRequest       // 完整請求
    
    // 回應資料
    let response: SuggestRecipeResponse     // 完整回應
    
    // 元資料
    var isFavorite: Bool                    // 是否收藏
    var customName: String?                 // 自訂名稱
    var tags: [String]                      // 標籤
    var usageCount: Int                     // 使用次數
    var lastUsedAt: Date?                   // 最後使用時間
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        requestHash: String,
        request: SuggestRecipeRequest,
        response: SuggestRecipeResponse,
        isFavorite: Bool = false,
        customName: String? = nil,
        tags: [String] = [],
        usageCount: Int = 1,
        lastUsedAt: Date? = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.requestHash = requestHash
        self.request = request
        self.response = response
        self.isFavorite = isFavorite
        self.customName = customName
        self.tags = tags
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
    }
}

// MARK: - QA 歷史記錄（未使用，保留以供未來擴展）
// struct QAHistory: Codable, Identifiable {
//     let id: String
//     let timestamp: Date
//     let recipeId: String?
//     let question: String
//     let stepDescription: String
//     let answer: String
//     let imageThumbnail: String?
//     var tags: [String]
// }

// MARK: - 索引檔案結構（輕量級）
struct RecipeHistoryIndex: Codable {
    var recipes: [RecipeHistoryIndexItem]
    var lastUpdated: Date
    
    init(recipes: [RecipeHistoryIndexItem] = [], lastUpdated: Date = Date()) {
        self.recipes = recipes
        self.lastUpdated = lastUpdated
    }
}

struct RecipeHistoryIndexItem: Codable {
    let id: String
    let dishName: String
    let timestamp: Date
    let requestHash: String
    let isFavorite: Bool
    let usageCount: Int
    let lastUsedAt: Date?
}

// QA 索引已移除，不再使用
// struct QAHistoryIndex: Codable { ... }
// struct QAHistoryIndexItem: Codable { ... }

// MARK: - 擴展：便利方法
extension RecipeHistory {
    /// 轉換為索引項目
    func toIndexItem() -> RecipeHistoryIndexItem {
        RecipeHistoryIndexItem(
            id: id,
            dishName: customName ?? response.dish_name,
            timestamp: timestamp,
            requestHash: requestHash,
            isFavorite: isFavorite,
            usageCount: usageCount,
            lastUsedAt: lastUsedAt
        )
    }
    
    /// 顯示用的名稱
    var displayName: String {
        customName ?? response.dish_name
    }
}

// QAHistory 擴展已移除

