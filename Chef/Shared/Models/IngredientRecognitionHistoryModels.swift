//
//  IngredientRecognitionHistoryModels.swift
//  ChefHelper
//
//  食材與設備辨識歷史記錄模型
//

import Foundation

// MARK: - 食材辨識歷史記錄
struct IngredientRecognitionHistory: Codable, Identifiable {
    let id: String                                      // UUID
    let timestamp: Date                                 // 建立時間
    let imageHash: String                               // 圖片的 hash 值，用於快取查找
    
    // 回應資料
    let response: IngredientRecognitionResponse         // 完整回應
    
    // 元資料
    var usageCount: Int                                 // 使用次數
    var lastUsedAt: Date?                               // 最後使用時間
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        imageHash: String,
        response: IngredientRecognitionResponse,
        usageCount: Int = 1,
        lastUsedAt: Date? = Date()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imageHash = imageHash
        self.response = response
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
    }
}

// MARK: - 索引檔案結構（輕量級）
struct IngredientRecognitionHistoryIndex: Codable {
    var records: [IngredientRecognitionHistoryIndexItem]
    var lastUpdated: Date
    
    init(records: [IngredientRecognitionHistoryIndexItem] = [], lastUpdated: Date = Date()) {
        self.records = records
        self.lastUpdated = lastUpdated
    }
}

struct IngredientRecognitionHistoryIndexItem: Codable {
    let id: String
    let summary: String                                 // 摘要
    let timestamp: Date
    let imageHash: String
    let ingredientCount: Int                            // 食材數量
    let equipmentCount: Int                             // 設備數量
    let usageCount: Int
    let lastUsedAt: Date?
}

// MARK: - 擴展：便利方法
extension IngredientRecognitionHistory {
    /// 轉換為索引項目
    func toIndexItem() -> IngredientRecognitionHistoryIndexItem {
        IngredientRecognitionHistoryIndexItem(
            id: id,
            summary: response.summary,
            timestamp: timestamp,
            imageHash: imageHash,
            ingredientCount: response.ingredients.count,
            equipmentCount: response.equipment.count,
            usageCount: usageCount,
            lastUsedAt: lastUsedAt
        )
    }
    
    /// 顯示用的名稱
    var displayName: String {
        let ingredientNames = response.ingredients.prefix(3).map { $0.name }.joined(separator: "、")
        if response.ingredients.count > 3 {
            return "\(ingredientNames) 等 \(response.ingredients.count) 種食材"
        }
        return ingredientNames
    }
}

