//
//  RecipeHistoryService.swift
//  ChefHelper
//
//  食譜歷史記錄儲存服務
//

import Foundation
import CryptoKit

final class RecipeHistoryService {
    static let shared = RecipeHistoryService()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // 檔案路徑
    private var recipesDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Recipes", isDirectory: true)
    }
    
    private var recipeIndexPath: URL {
        recipesDirectory.appendingPathComponent("index.json")
    }
    
    // QA 目錄已移除，不再使用
    
    // 記憶體快取
    private var recipeCache: [String: RecipeHistory] = [:]
    private var hashToIdMap: [String: String] = [:]
    
    private init() {
        setupDirectories()
        loadIndexToCache()
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: recipesDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ RecipeHistoryService: 建立目錄失敗 - \(error)")
        }
    }
    
    private func loadIndexToCache() {
        // 載入索引到快取
        if let index = loadRecipeIndex() {
            hashToIdMap = Dictionary(uniqueKeysWithValues: index.recipes.map { ($0.requestHash, $0.id) })
        }
    }
    
    // MARK: - Hash Calculation
    
    /// 計算請求的 hash 值（SuggestRecipeRequest）
    func calculateRequestHash(_ request: SuggestRecipeRequest) -> String {
        encoder.outputFormatting = .sortedKeys
        
        // 建立標準化的請求（排序陣列）
        let sortedIngredients = request.available_ingredients.sorted { $0.name < $1.name }
        let sortedEquipment = request.available_equipment.sorted { $0.name < $1.name }
        let sortedRestrictions = request.preference.dietary_restrictions.sorted()
        
        let normalizedRequest = SuggestRecipeRequest(
            available_ingredients: sortedIngredients,
            available_equipment: sortedEquipment,
            preference: Preference(
                cooking_method: request.preference.cooking_method,
                dietary_restrictions: sortedRestrictions,
                serving_size: request.preference.serving_size,
                recipe_description: request.preference.recipe_description
            )
        )
        
        guard let data = try? encoder.encode(normalizedRequest) else {
            return UUID().uuidString
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// 計算請求的 hash 值（GenerateRecipeByNameRequest）
    func calculateRequestHash(_ request: GenerateRecipeByNameRequest) -> String {
        encoder.outputFormatting = .sortedKeys
        
        // 建立標準化的請求（排序陣列）
        let normalizedRequest = GenerateRecipeByNameRequest(
            dish_name: request.dish_name,
            preferred_ingredients: request.preferred_ingredients.sorted(),
            excluded_ingredients: request.excluded_ingredients.sorted(),
            preferred_equipment: request.preferred_equipment.sorted(),
            preference: request.preference
        )
        
        guard let data = try? encoder.encode(normalizedRequest) else {
            return UUID().uuidString
        }
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Recipe History - Save
    
    /// 儲存食譜歷史記錄（從 SuggestRecipeRequest）
    @discardableResult
    func save(request: SuggestRecipeRequest, response: SuggestRecipeResponse) -> RecipeHistory? {
        let requestHash = calculateRequestHash(request)
        
        // 檢查是否已存在
        if let existingId = hashToIdMap[requestHash],
           var existing = load(id: existingId) {
            // 更新使用次數
            existing.usageCount += 1
            existing.lastUsedAt = Date()
            return update(existing)
        }
        
        // 建立新記錄
        let history = RecipeHistory(
            requestHash: requestHash,
            request: request,
            response: response
        )
        
        // 儲存到檔案
        do {
            let filePath = recipesDirectory.appendingPathComponent("\(history.id).json")
            let data = try encoder.encode(history)
            try data.write(to: filePath)
            
            // 更新快取
            recipeCache[history.id] = history
            hashToIdMap[requestHash] = history.id
            
            // 更新索引
            updateRecipeIndex(with: history)
            
            print("💾 RecipeHistoryService: 已儲存食譜 - \(response.dish_name)")
            return history
        } catch {
            print("❌ RecipeHistoryService: 儲存失敗 - \(error)")
            return nil
        }
    }
    
    /// 儲存食譜歷史記錄（從 GenerateRecipeByNameRequest）
    @discardableResult
    func saveFromFoodRecipe(
        request: GenerateRecipeByNameRequest,
        response: SuggestRecipeResponse
    ) -> RecipeHistory? {
        // 使用和計算 hash 相同的標準化方式
        let requestHash = calculateRequestHash(request)
        
        // 檢查是否已存在
        if let existingId = hashToIdMap[requestHash],
           var existing = load(id: existingId) {
            // 更新使用次數
            existing.usageCount += 1
            existing.lastUsedAt = Date()
            return update(existing)
        }
        
        // 轉換為 SuggestRecipeRequest 格式以便儲存（使用排序後的陣列）
        let convertedRequest = convertToSuggestRecipeRequest(
            from: request,
            sortIngredients: true,
            sortEquipment: true
        )
        
        // 建立新記錄
        let history = RecipeHistory(
            requestHash: requestHash,
            request: convertedRequest,
            response: response
        )
        
        // 儲存到檔案
        do {
            let filePath = recipesDirectory.appendingPathComponent("\(history.id).json")
            let data = try encoder.encode(history)
            try data.write(to: filePath)
            
            // 更新快取
            recipeCache[history.id] = history
            hashToIdMap[requestHash] = history.id
            
            // 更新索引
            updateRecipeIndex(with: history)
            
            print("💾 RecipeHistoryService: 已儲存食譜 - \(response.dish_name)")
            return history
        } catch {
            print("❌ RecipeHistoryService: 儲存失敗 - \(error)")
            return nil
        }
    }
    
    /// 將 GenerateRecipeByNameRequest 轉換為 SuggestRecipeRequest
    private func convertToSuggestRecipeRequest(
        from request: GenerateRecipeByNameRequest,
        sortIngredients: Bool = false,
        sortEquipment: Bool = false
    ) -> SuggestRecipeRequest {
        let ingredientNames = sortIngredients ? request.preferred_ingredients.sorted() : request.preferred_ingredients
        let ingredients = ingredientNames.map { name in
            Ingredient(name: name, type: "食材", amount: "適量", unit: "", preparation: "")
        }
        
        let equipmentNames = sortEquipment ? request.preferred_equipment.sorted() : request.preferred_equipment
        let equipment = equipmentNames.map { name in
            Equipment(name: name, type: "器具", size: "", material: "", power_source: "")
        }
        
        let sortedRestrictions = request.excluded_ingredients.sorted()
        
        let preference = Preference(
            cooking_method: request.preference.cooking_method ?? "一般烹調",
            dietary_restrictions: sortedRestrictions,
            serving_size: request.preference.serving_size,
            recipe_description: "基於 \(request.dish_name) 生成"
        )
        
        return SuggestRecipeRequest(
            available_ingredients: ingredients,
            available_equipment: equipment,
            preference: preference
        )
    }
    
    // MARK: - Recipe History - Load
    
    /// 根據 ID 載入食譜
    func load(id: String) -> RecipeHistory? {
        // 先檢查快取
        if let cached = recipeCache[id] {
            return cached
        }
        
        // 從檔案載入
        let filePath = recipesDirectory.appendingPathComponent("\(id).json")
        
        do {
            let data = try Data(contentsOf: filePath)
            let history = try decoder.decode(RecipeHistory.self, from: data)
            
            // 更新快取
            recipeCache[id] = history
            
            return history
        } catch {
            print("❌ RecipeHistoryService: 載入失敗 - \(error)")
            return nil
        }
    }
    
    /// 根據 hash 查找食譜（快取命中）
    func findByHash(_ hash: String) -> RecipeHistory? {
        guard let id = hashToIdMap[hash] else {
            return nil
        }
        return load(id: id)
    }
    
    /// 載入所有食譜
    func fetchAll() -> [RecipeHistory] {
        guard let index = loadRecipeIndex() else {
            return []
        }
        
        return index.recipes.compactMap { load(id: $0.id) }
    }
    
    /// 載入最近的食譜
    func fetchRecent(limit: Int = 10) -> [RecipeHistory] {
        let all = fetchAll()
        return Array(all.sorted { ($0.lastUsedAt ?? $0.timestamp) > ($1.lastUsedAt ?? $1.timestamp) }.prefix(limit))
    }
    
    /// 載入收藏的食譜
    func fetchFavorites() -> [RecipeHistory] {
        fetchAll().filter { $0.isFavorite }
    }
    
    // MARK: - Recipe History - Update
    
    /// 更新食譜記錄
    @discardableResult
    func update(_ history: RecipeHistory) -> RecipeHistory? {
        let filePath = recipesDirectory.appendingPathComponent("\(history.id).json")
        
        do {
            let data = try encoder.encode(history)
            try data.write(to: filePath)
            
            // 更新快取
            recipeCache[history.id] = history
            
            // 更新索引
            updateRecipeIndex(with: history)
            
            print("✏️ RecipeHistoryService: 已更新食譜 - \(history.id)")
            return history
        } catch {
            print("❌ RecipeHistoryService: 更新失敗 - \(error)")
            return nil
        }
    }
    
    /// 更新使用次數
    func incrementUsage(id: String) {
        guard var history = load(id: id) else { return }
        
        history.usageCount += 1
        history.lastUsedAt = Date()
        update(history)
    }
    
    /// 切換收藏狀態
    func toggleFavorite(id: String) {
        guard var history = load(id: id) else { return }
        
        history.isFavorite.toggle()
        update(history)
    }
    
    // MARK: - Recipe History - Delete
    
    /// 刪除食譜
    func delete(id: String) {
        let filePath = recipesDirectory.appendingPathComponent("\(id).json")
        
        do {
            try fileManager.removeItem(at: filePath)
            
            // 從快取移除
            recipeCache.removeValue(forKey: id)
            
            // 從 hash map 移除
            if let history = recipeCache[id] {
                hashToIdMap.removeValue(forKey: history.requestHash)
            }
            
            // 更新索引
            removeFromRecipeIndex(id: id)
            
            print("🗑️ RecipeHistoryService: 已刪除食譜 - \(id)")
        } catch {
            print("❌ RecipeHistoryService: 刪除失敗 - \(error)")
        }
    }
    
    /// 清除所有食譜
    func deleteAll() {
        do {
            let files = try fileManager.contentsOfDirectory(at: recipesDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            
            recipeCache.removeAll()
            hashToIdMap.removeAll()
            
            // 重建空索引
            saveRecipeIndex(RecipeHistoryIndex())
            
            print("🗑️ RecipeHistoryService: 已清除所有食譜")
        } catch {
            print("❌ RecipeHistoryService: 清除失敗 - \(error)")
        }
    }
    
    // MARK: - Index Management
    
    private func loadRecipeIndex() -> RecipeHistoryIndex? {
        guard fileManager.fileExists(atPath: recipeIndexPath.path) else {
            return RecipeHistoryIndex()
        }
        
        do {
            let data = try Data(contentsOf: recipeIndexPath)
            return try decoder.decode(RecipeHistoryIndex.self, from: data)
        } catch {
            print("❌ RecipeHistoryService: 載入索引失敗 - \(error)")
            return nil
        }
    }
    
    private func saveRecipeIndex(_ index: RecipeHistoryIndex) {
        do {
            let data = try encoder.encode(index)
            try data.write(to: recipeIndexPath)
        } catch {
            print("❌ RecipeHistoryService: 儲存索引失敗 - \(error)")
        }
    }
    
    private func updateRecipeIndex(with history: RecipeHistory) {
        var index = loadRecipeIndex() ?? RecipeHistoryIndex()
        
        // 移除舊的（如果存在）
        index.recipes.removeAll { $0.id == history.id }
        
        // 加入新的
        index.recipes.append(history.toIndexItem())
        index.lastUpdated = Date()
        
        saveRecipeIndex(index)
    }
    
    private func removeFromRecipeIndex(id: String) {
        var index = loadRecipeIndex() ?? RecipeHistoryIndex()
        index.recipes.removeAll { $0.id == id }
        index.lastUpdated = Date()
        saveRecipeIndex(index)
    }
    
    // MARK: - QA History (已移除，未來如需要可再實作)
    
    // MARK: - Statistics
    
    /// 獲取統計資訊
    func getStatistics() -> (totalRecipes: Int, favorites: Int) {
        let recipes = fetchAll()
        let favorites = recipes.filter { $0.isFavorite }.count
        
        return (recipes.count, favorites)
    }
}

