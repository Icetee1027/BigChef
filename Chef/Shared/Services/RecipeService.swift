import Foundation

enum RecipeService {
    private static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""
    }
    // MARK: - 食譜生成 async 函式
    static func generateRecipe(using request: SuggestRecipeRequest) async throws -> SuggestRecipeResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/recipe/suggest") else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🟢 發送食譜生成請求：\n\(jsonString)")
            }
        } catch {
            print("❌ 請求編碼失敗：\(error)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 無效的伺服器回應")
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ HTTP 錯誤：\(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoded = try JSONDecoder().decode(SuggestRecipeResponse.self, from: data)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ AI 回傳食譜：\n\(jsonString)")
            }
            return decoded
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("🔴 AI 回傳原始資料：\n\(raw)")
            }
            print("❌ 解碼失敗：\(error)")
            throw error
        }
    }
    // MARK: - 掃描圖片為食材與設備
    static func scanImageForIngredients(using request: ScanImageRequest) async throws -> ScanImageResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/recipe/ingredient") else {
            print("❌ 無效的 URL")
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let requestInfo = """
            🟢 發送圖片掃描請求：
            描述提示：\(request.description_hint)
            圖片大小：\(request.image.count) 字元
            """
            print(requestInfo)
        } catch {
            print("❌ 請求編碼失敗：\(error)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 無效的伺服器回應")
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ HTTP 錯誤：\(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        do {
            let decoded = try JSONDecoder().decode(ScanImageResponse.self, from: data)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ AI 回傳掃描結果：\n\(jsonString)")
                print("📝 識別摘要：\(decoded.summary)")
                print("🥬 識別出 \(decoded.ingredients.count) 個食材")
                print("🔧 識別出 \(decoded.equipment.count) 個設備")
            }
            return decoded
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("🔴 AI 回傳原始資料：\n\(raw)")
            }
            print("❌ 解碼失敗：\(error)")
            throw error
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .invalidResponse:
            return "無效的伺服器回應"
        case .httpError(let code):
            return "HTTP 錯誤：\(code)"
        case .noData:
            return "沒有收到資料"
        case .unknown(let message):
            return "未知錯誤：\(message)"
        }
    }
}
