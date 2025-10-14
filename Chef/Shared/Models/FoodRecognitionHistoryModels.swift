//
//  FoodRecognitionHistoryModels.swift
//  ChefHelper
//
//  食物辨識歷史記錄模型
//

import Foundation

// MARK: - 食物辨識歷史記錄
struct FoodRecognitionHistory: Codable, Identifiable {
    let id: String                                  // UUID
    let timestamp: Date                             // 建立時間
    let imageHash: String                           // 圖片的 hash 值，用於快取查找
    
    // 回應資料
    let response: FoodRecognitionResponse           // 完整回應
    
    // 元資料
    var usageCount: Int                             // 使用次數
    var lastUsedAt: Date?                           // 最後使用時間
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        imageHash: String,
        response: FoodRecognitionResponse,
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
struct FoodRecognitionHistoryIndex: Codable {
    var records: [FoodRecognitionHistoryIndexItem]
    var lastUpdated: Date
    
    init(records: [FoodRecognitionHistoryIndexItem] = [], lastUpdated: Date = Date()) {
        self.records = records
        self.lastUpdated = lastUpdated
    }
}

struct FoodRecognitionHistoryIndexItem: Codable {
    let id: String
    let foodName: String                            // 主要食物名稱
    let timestamp: Date
    let imageHash: String
    let usageCount: Int
    let lastUsedAt: Date?
}

// MARK: - 擴展：便利方法
extension FoodRecognitionHistory {
    /// 轉換為索引項目
    func toIndexItem() -> FoodRecognitionHistoryIndexItem {
        FoodRecognitionHistoryIndexItem(
            id: id,
            foodName: response.primaryFood?.name ?? "未知食物",
            timestamp: timestamp,
            imageHash: imageHash,
            usageCount: usageCount,
            lastUsedAt: lastUsedAt
        )
    }
    
    /// 顯示用的名稱
    var displayName: String {
        response.primaryFood?.name ?? "未知食物"
    }
}

