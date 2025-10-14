//
//  HistoryViewModel.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/8.
//

import Foundation
import SwiftUI

// MARK: - 歷史記錄類型
enum HistoryType: String, CaseIterable {
    case recipes = "食譜生成"
    case foodRecognition = "食物辨識"
    case ingredientRecognition = "食材設備"
    
    var icon: String {
        switch self {
        case .recipes: return "book.fill"
        case .foodRecognition: return "camera.fill"
        case .ingredientRecognition: return "leaf.fill"
        }
    }
}

// MARK: - 歷史記錄篩選器
enum HistoryFilter: String, CaseIterable {
    case all = "全部"
    case favorites = "收藏"
    case recent = "最近"
    
    var icon: String {
        switch self {
        case .all: return "clock.arrow.circlepath"
        case .favorites: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

// MARK: - 歷史記錄排序
enum HistorySortOrder: String, CaseIterable {
    case dateDesc = "最新優先"
    case dateAsc = "最舊優先"
    case usageCount = "使用次數"
    case dishName = "菜名"
}

final class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedHistoryType: HistoryType = .recipes
    
    @Published var recipeHistories: [RecipeHistory] = []
    @Published var foodRecognitionHistories: [FoodRecognitionHistory] = []
    @Published var ingredientRecognitionHistories: [IngredientRecognitionHistory] = []
    
    @Published var selectedFilter: HistoryFilter = .all
    @Published var selectedSortOrder: HistorySortOrder = .dateDesc
    @Published var searchText: String = ""
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Callbacks
    var onReuseRecipe: ((RecipeHistory) -> Void)?
    var onReuseFoodRecognition: ((FoodRecognitionHistory) -> Void)?
    var onReuseIngredientRecognition: ((IngredientRecognitionHistory) -> Void)?
    
    // MARK: - Private Properties
    private let recipeHistoryService = RecipeHistoryService.shared
    private let foodRecognitionHistoryService = FoodRecognitionHistoryService.shared
    private let ingredientRecognitionHistoryService = IngredientRecognitionHistoryService.shared
    
    // MARK: - Computed Properties
    
    /// 篩選後的食譜列表
    var filteredRecipes: [RecipeHistory] {
        var recipes = recipeHistories
        
        // 根據篩選器
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            recipes = recipes.filter { $0.isFavorite }
        case .recent:
            recipes = Array(recipes.sorted { 
                ($0.lastUsedAt ?? $0.timestamp) > ($1.lastUsedAt ?? $1.timestamp) 
            }.prefix(20))
        }
        
        // 搜尋
        if !searchText.isEmpty {
            recipes = recipes.filter { history in
                history.displayName.localizedCaseInsensitiveContains(searchText) ||
                history.response.dish_description.localizedCaseInsensitiveContains(searchText) ||
                history.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 排序
        switch selectedSortOrder {
        case .dateDesc:
            recipes.sort { $0.timestamp > $1.timestamp }
        case .dateAsc:
            recipes.sort { $0.timestamp < $1.timestamp }
        case .usageCount:
            recipes.sort { $0.usageCount > $1.usageCount }
        case .dishName:
            recipes.sort { $0.displayName < $1.displayName }
        }
        
        return recipes
    }
    
    /// 統計資訊
    var statistics: (total: Int, favorites: Int) {
        switch selectedHistoryType {
        case .recipes:
            let stats = recipeHistoryService.getStatistics()
            return (total: stats.totalRecipes, favorites: stats.favorites)
        case .foodRecognition:
            let stats = foodRecognitionHistoryService.getStatistics()
            return (total: stats.total, favorites: 0)
        case .ingredientRecognition:
            let stats = ingredientRecognitionHistoryService.getStatistics()
            return (total: stats.total, favorites: 0)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadHistories()
    }
    
    // MARK: - Public Methods
    
    /// 載入歷史記錄
    func loadHistories() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            let recipes = self.recipeHistoryService.fetchAll()
            let foodRecognition = self.foodRecognitionHistoryService.fetchAll()
            let ingredientRecognition = self.ingredientRecognitionHistoryService.fetchAll()
            
            DispatchQueue.main.async {
                self.recipeHistories = recipes
                self.foodRecognitionHistories = foodRecognition
                self.ingredientRecognitionHistories = ingredientRecognition
                self.isLoading = false
            }
        }
    }
    
    /// 重新載入
    func refresh() {
        loadHistories()
    }
    
    /// 切換收藏狀態
    func toggleFavorite(id: String) {
        recipeHistoryService.toggleFavorite(id: id)
        
        // 更新本地狀態
        if let index = recipeHistories.firstIndex(where: { $0.id == id }) {
            recipeHistories[index].isFavorite.toggle()
        }
    }
    
    /// 刪除記錄
    func deleteRecord(id: String) {
        switch selectedHistoryType {
        case .recipes:
            recipeHistoryService.delete(id: id)
            recipeHistories.removeAll { $0.id == id }
        case .foodRecognition:
            foodRecognitionHistoryService.delete(id: id)
            foodRecognitionHistories.removeAll { $0.id == id }
        case .ingredientRecognition:
            ingredientRecognitionHistoryService.delete(id: id)
            ingredientRecognitionHistories.removeAll { $0.id == id }
        }
    }
    
    /// 清除所有歷史
    func clearAllHistory() {
        switch selectedHistoryType {
        case .recipes:
            recipeHistoryService.deleteAll()
            recipeHistories.removeAll()
        case .foodRecognition:
            foodRecognitionHistoryService.deleteAll()
            foodRecognitionHistories.removeAll()
        case .ingredientRecognition:
            ingredientRecognitionHistoryService.deleteAll()
            ingredientRecognitionHistories.removeAll()
        }
    }
    
    /// 根據 ID 獲取食譜
    func getRecipe(id: String) -> RecipeHistory? {
        recipeHistories.first { $0.id == id }
    }
    
    /// 增加使用次數
    func incrementUsage(id: String) {
        switch selectedHistoryType {
        case .recipes:
            recipeHistoryService.incrementUsage(id: id)
            if let index = recipeHistories.firstIndex(where: { $0.id == id }) {
                recipeHistories[index].usageCount += 1
                recipeHistories[index].lastUsedAt = Date()
            }
        case .foodRecognition:
            foodRecognitionHistoryService.incrementUsage(id: id)
            if let index = foodRecognitionHistories.firstIndex(where: { $0.id == id }) {
                foodRecognitionHistories[index].usageCount += 1
                foodRecognitionHistories[index].lastUsedAt = Date()
            }
        case .ingredientRecognition:
            ingredientRecognitionHistoryService.incrementUsage(id: id)
            if let index = ingredientRecognitionHistories.firstIndex(where: { $0.id == id }) {
                ingredientRecognitionHistories[index].usageCount += 1
                ingredientRecognitionHistories[index].lastUsedAt = Date()
            }
        }
    }
    
    /// 格式化日期
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    /// 格式化相對時間
    func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分鐘前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小時前"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}
