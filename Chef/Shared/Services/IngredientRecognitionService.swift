//
//  IngredientRecognitionService.swift
//  ChefHelper
//
//  Created by Claude on 2025/10/01.
//

import Foundation
import UIKit

// MARK: - Request & Response Models

struct IngredientRecognitionRequest: Codable {
    let image: String
    let description_hint: String?
}

struct IngredientRecognitionResponse: Codable {
    let ingredients: [RecognizedIngredient]
    let equipment: [RecognizedEquipment]
    let summary: String
}

struct RecognizedIngredient: Codable, Identifiable {
    var id = UUID()  // 本地唯一識別碼，只給 SwiftUI 用，不會進 JSON
    let name: String
    let type: String
    let amount: String
    let unit: String
    let preparation: String
    
    // 不讓 id 編碼或解碼
    private enum CodingKeys: String, CodingKey {
        case name, type, amount, unit, preparation
    }
}

struct RecognizedEquipment: Codable, Identifiable {
    var id = UUID()  // 本地唯一識別碼，只給 SwiftUI 用，不會進 JSON
    let name: String
    let type: String
    let size: String
    let material: String
    let power_source: String
    
    // 不讓 id 編碼或解碼
    private enum CodingKeys: String, CodingKey {
        case name, type, size, material, power_source
    }
}

// MARK: - Service

class IngredientRecognitionService {
    static let shared = IngredientRecognitionService()

    private static var baseURL: String {
        return ConfigManager.shared.apiBaseURL
    }

    private init() {}

    /// 辨識食材和器具圖片
    func recognizeIngredients(image: UIImage, hint: String? = nil) async throws -> IngredientRecognitionResponse {
        // 🔍 檢查快取
        if let cachedHistory = IngredientRecognitionHistoryService.shared.findByImage(image) {
            print("✅ 從快取載入食材辨識結果")
            print("   食材：\(cachedHistory.response.ingredients.count) 種")
            print("   器具：\(cachedHistory.response.equipment.count) 種")
            print("⏱️ 上次使用：\(formatTimeSince(cachedHistory.lastUsedAt ?? cachedHistory.timestamp))")
            
            // 更新使用次數
            IngredientRecognitionHistoryService.shared.incrementUsage(id: cachedHistory.id)
            
            return cachedHistory.response
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw IngredientRecognitionError.imageProcessingFailed
        }

        let base64Image = "data:image/jpeg;base64,\(imageData.base64EncodedString())"

        let request = IngredientRecognitionRequest(
            image: base64Image,
            description_hint: hint
        )

        guard let url = URL(string: "\(Self.baseURL)/api/v1/recipe/ingredient") else {
            throw IngredientRecognitionError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)

            print("📤 發送食材辨識請求：\(url)")
            if let hint = hint {
                print("   提示：\(hint)")
            }

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw IngredientRecognitionError.invalidResponse
            }

            print("📥 收到回應，狀態碼：\(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                throw IngredientRecognitionError.serverError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(IngredientRecognitionResponse.self, from: data)

            print("✅ 辨識成功")
            print("   食材數量：\(result.ingredients.count)")
            print("   器具數量：\(result.equipment.count)")
            print("   摘要：\(result.summary)")

            // 💾 儲存到歷史記錄（只有成功的回應才儲存）
            IngredientRecognitionHistoryService.shared.save(image: image, response: result)

            return result

        } catch let error as DecodingError {
            print("❌ JSON 解析失敗：\(error)")
            throw IngredientRecognitionError.decodingFailed
        } catch {
            print("❌ 網路請求失敗：\(error)")
            throw IngredientRecognitionError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTimeSince(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分鐘前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小時前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}

// MARK: - Error Types

enum IngredientRecognitionError: LocalizedError {
    case imageProcessingFailed
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "圖片處理失敗"
        case .invalidURL:
            return "無效的 URL"
        case .invalidResponse:
            return "無效的回應"
        case .serverError(let code):
            return "伺服器錯誤 (\(code))"
        case .decodingFailed:
            return "資料解析失敗"
        case .networkError(let message):
            return "網路錯誤：\(message)"
        }
    }
}
