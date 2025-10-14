//
//  RecipeRecommendationResponse.swift
//  ChefHelper
//
//  Created by Claude on 2025/9/22.
//

import Foundation

// MARK: - Recipe Recommendation Response Model
// 重用現有的 Ingredient, Equipment, RecipeStep, Action 模型

struct RecipeRecommendationResponse: Codable {
    let dishName: String
    let dishDescription: String
    let ingredients: [Ingredient]
    let equipment: [Equipment]
    let recipe: [RecipeStep]
    
    // 快取相關屬性（不參與編碼）
    var isFromCache: Bool = false
    var cacheTimestamp: Date?
    var historyId: String?

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case dishDescription = "dish_description"
        case ingredients, equipment, recipe
        // isFromCache, cacheTimestamp, historyId 不編碼
    }
}

// MARK: - Extensions for convenience

extension RecipeRecommendationResponse {
    /// 總步驟數
    var totalSteps: Int {
        recipe.count
    }
    
    /// 預估總時間
    var totalEstimatedTime: String {
        recipe.first?.estimated_total_time ?? "未知"
    }
    
    /// 快取資訊描述
    var cacheDescription: String? {
        guard isFromCache, let timestamp = cacheTimestamp else {
            return nil
        }
        
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "從快取載入（剛剛）"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "從快取載入（\(minutes)分鐘前）"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "從快取載入（\(hours)小時前）"
        } else {
            let days = Int(interval / 86400)
            return "從快取載入（\(days)天前）"
        }
    }
    
    static func sample() -> RecipeRecommendationResponse {
        let sampleIngredient = Ingredient(
            name: "蛋",
            type: "蛋類",
            amount: "2",
            unit: "顆",
            preparation: "打散"
        )

        let sampleEquipment = Equipment(
            name: "平底鍋",
            type: "鍋具",
            size: "小型",
            material: "不沾",
            power_source: "電"
        )

        let sampleAction = Action(
            action: "煎",
            tool_required: "平底鍋",
            material_required: ["蛋"],
            time_minutes: "3",
            instruction_detail: "蛋液均勻攤平"
        )

        let sampleStep = RecipeStep(
            step_number: 1,
            title: "煎蛋",
            description: "將蛋液倒入鍋中，小火煎熟。",
            actions: [sampleAction],
            estimated_total_time: "3分鐘",
            temperature: "小火",
            warnings: nil,
            notes: "可加鹽調味"
        )

        return RecipeRecommendationResponse(
            dishName: "煎蛋",
            dishDescription: "簡單快速的早餐料理",
            ingredients: [sampleIngredient],
            equipment: [sampleEquipment],
            recipe: [sampleStep]
        )
    }

    // Helper computed properties (已移至擴展中第36-44行，避免重複定義)
    // totalSteps 和 totalEstimatedTime 已在擴展中定義

    var allIngredientNames: [String] {
        ingredients.map { $0.name }
    }

    var allEquipmentNames: [String] {
        equipment.map { $0.name }
    }
}