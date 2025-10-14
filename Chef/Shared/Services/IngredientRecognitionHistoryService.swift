//
//  IngredientRecognitionHistoryService.swift
//  ChefHelper
//
//  食材與設備辨識歷史記錄儲存服務
//

import Foundation
import UIKit
import CryptoKit

final class IngredientRecognitionHistoryService {
    static let shared = IngredientRecognitionHistoryService()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // 檔案路徑
    private var ingredientRecognitionDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("IngredientRecognition", isDirectory: true)
    }
    
    private var indexPath: URL {
        ingredientRecognitionDirectory.appendingPathComponent("index.json")
    }
    
    // 記憶體快取
    private var cache: [String: IngredientRecognitionHistory] = [:]
    private var hashToIdMap: [String: String] = [:]
    
    private init() {
        setupDirectories()
        loadIndexToCache()
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: ingredientRecognitionDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ IngredientRecognitionHistoryService: 建立目錄失敗 - \(error)")
        }
    }
    
    private func loadIndexToCache() {
        if let index = loadIndex() {
            hashToIdMap = Dictionary(uniqueKeysWithValues: index.records.map { ($0.imageHash, $0.id) })
        }
    }
    
    // MARK: - Hash Calculation
    
    /// 計算圖片的 hash 值
    func calculateImageHash(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Save
    
    /// 儲存食材辨識歷史記錄
    @discardableResult
    func save(image: UIImage, response: IngredientRecognitionResponse) -> IngredientRecognitionHistory? {
        guard let imageHash = calculateImageHash(image) else {
            print("❌ IngredientRecognitionHistoryService: 無法計算圖片 hash")
            return nil
        }
        
        // 檢查是否已存在
        if let existingId = hashToIdMap[imageHash],
           var existing = load(id: existingId) {
            // 更新使用次數
            existing.usageCount += 1
            existing.lastUsedAt = Date()
            return update(existing)
        }
        
        // 建立新記錄
        let history = IngredientRecognitionHistory(
            imageHash: imageHash,
            response: response
        )
        
        // 儲存到檔案
        do {
            let filePath = ingredientRecognitionDirectory.appendingPathComponent("\(history.id).json")
            let data = try encoder.encode(history)
            try data.write(to: filePath)
            
            // 更新快取
            cache[history.id] = history
            hashToIdMap[imageHash] = history.id
            
            // 更新索引
            updateIndex(with: history)
            
            print("💾 IngredientRecognitionHistoryService: 已儲存食材辨識 - \(history.displayName)")
            return history
        } catch {
            print("❌ IngredientRecognitionHistoryService: 儲存失敗 - \(error)")
            return nil
        }
    }
    
    // MARK: - Load
    
    /// 根據 ID 載入記錄
    func load(id: String) -> IngredientRecognitionHistory? {
        // 先檢查快取
        if let cached = cache[id] {
            return cached
        }
        
        // 從檔案載入
        let filePath = ingredientRecognitionDirectory.appendingPathComponent("\(id).json")
        
        do {
            let data = try Data(contentsOf: filePath)
            let history = try decoder.decode(IngredientRecognitionHistory.self, from: data)
            
            // 更新快取
            cache[id] = history
            
            return history
        } catch {
            print("❌ IngredientRecognitionHistoryService: 載入失敗 - \(error)")
            return nil
        }
    }
    
    /// 根據 hash 查找記錄（快取命中）
    func findByHash(_ hash: String) -> IngredientRecognitionHistory? {
        guard let id = hashToIdMap[hash] else {
            return nil
        }
        return load(id: id)
    }
    
    /// 根據圖片查找記錄
    func findByImage(_ image: UIImage) -> IngredientRecognitionHistory? {
        guard let hash = calculateImageHash(image) else {
            return nil
        }
        return findByHash(hash)
    }
    
    /// 載入所有記錄
    func fetchAll() -> [IngredientRecognitionHistory] {
        guard let index = loadIndex() else {
            return []
        }
        
        return index.records.compactMap { load(id: $0.id) }
    }
    
    /// 載入最近的記錄
    func fetchRecent(limit: Int = 20) -> [IngredientRecognitionHistory] {
        let all = fetchAll()
        return Array(all.sorted { ($0.lastUsedAt ?? $0.timestamp) > ($1.lastUsedAt ?? $1.timestamp) }.prefix(limit))
    }
    
    // MARK: - Update
    
    /// 更新記錄
    @discardableResult
    func update(_ history: IngredientRecognitionHistory) -> IngredientRecognitionHistory? {
        let filePath = ingredientRecognitionDirectory.appendingPathComponent("\(history.id).json")
        
        do {
            let data = try encoder.encode(history)
            try data.write(to: filePath)
            
            // 更新快取
            cache[history.id] = history
            
            // 更新索引
            updateIndex(with: history)
            
            print("✏️ IngredientRecognitionHistoryService: 已更新記錄 - \(history.id)")
            return history
        } catch {
            print("❌ IngredientRecognitionHistoryService: 更新失敗 - \(error)")
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
    
    // MARK: - Delete
    
    /// 刪除記錄
    func delete(id: String) {
        let filePath = ingredientRecognitionDirectory.appendingPathComponent("\(id).json")
        
        do {
            try fileManager.removeItem(at: filePath)
            
            // 從快取移除
            if let history = cache[id] {
                hashToIdMap.removeValue(forKey: history.imageHash)
            }
            cache.removeValue(forKey: id)
            
            // 更新索引
            removeFromIndex(id: id)
            
            print("🗑️ IngredientRecognitionHistoryService: 已刪除記錄 - \(id)")
        } catch {
            print("❌ IngredientRecognitionHistoryService: 刪除失敗 - \(error)")
        }
    }
    
    /// 清除所有記錄
    func deleteAll() {
        do {
            let files = try fileManager.contentsOfDirectory(at: ingredientRecognitionDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            
            cache.removeAll()
            hashToIdMap.removeAll()
            
            // 重建空索引
            saveIndex(IngredientRecognitionHistoryIndex())
            
            print("🗑️ IngredientRecognitionHistoryService: 已清除所有記錄")
        } catch {
            print("❌ IngredientRecognitionHistoryService: 清除失敗 - \(error)")
        }
    }
    
    // MARK: - Index Management
    
    private func loadIndex() -> IngredientRecognitionHistoryIndex? {
        guard fileManager.fileExists(atPath: indexPath.path) else {
            return IngredientRecognitionHistoryIndex()
        }
        
        do {
            let data = try Data(contentsOf: indexPath)
            return try decoder.decode(IngredientRecognitionHistoryIndex.self, from: data)
        } catch {
            print("❌ IngredientRecognitionHistoryService: 載入索引失敗 - \(error)")
            return nil
        }
    }
    
    private func saveIndex(_ index: IngredientRecognitionHistoryIndex) {
        do {
            let data = try encoder.encode(index)
            try data.write(to: indexPath)
        } catch {
            print("❌ IngredientRecognitionHistoryService: 儲存索引失敗 - \(error)")
        }
    }
    
    private func updateIndex(with history: IngredientRecognitionHistory) {
        var index = loadIndex() ?? IngredientRecognitionHistoryIndex()
        
        // 移除舊的（如果存在）
        index.records.removeAll { $0.id == history.id }
        
        // 加入新的
        index.records.append(history.toIndexItem())
        index.lastUpdated = Date()
        
        saveIndex(index)
    }
    
    private func removeFromIndex(id: String) {
        var index = loadIndex() ?? IngredientRecognitionHistoryIndex()
        index.records.removeAll { $0.id == id }
        index.lastUpdated = Date()
        saveIndex(index)
    }
    
    // MARK: - Statistics
    
    /// 獲取統計資訊
    func getStatistics() -> (total: Int, totalIngredients: Int, totalEquipment: Int) {
        let all = fetchAll()
        let totalIngredients = all.reduce(0) { $0 + $1.response.ingredients.count }
        let totalEquipment = all.reduce(0) { $0 + $1.response.equipment.count }
        return (all.count, totalIngredients, totalEquipment)
    }
}

