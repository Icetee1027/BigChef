import Foundation

enum RecipeService {
    private static var baseURL: String {
        return ConfigManager.shared.apiBaseURL
    }
    // MARK: - 依名稱/偏好生成食譜 async 函式
    static func generateRecipeByName(using request: GenerateRecipeByNameRequest) async throws -> SuggestRecipeResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/recipe/generate") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🟢 發送依名稱生成食譜請求：\n\(jsonString)")
                print("🍽️ 目標菜名：\(request.dish_name)")
                print("👥 份量：\(request.preference.serving_size)")
            }
        } catch {
            print("❌ 依名稱生成食譜請求編碼失敗：\(error)")
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
                print("✅ AI 回傳依名稱生成的食譜：\n\(jsonString)")
                print("🍽️ 生成食譜：\(decoded.dish_name)")
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

    // MARK: - 基於辨識食物生成製作食譜 async 函式（舊的，保留向後兼容）
    static func generateRecipeForRecognizedFood(using request: RecognizedFoodRecipeRequest) async throws -> SuggestRecipeResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/recipe/recognized-food") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🟢 發送辨識食物食譜生成請求：\n\(jsonString)")
                print("📋 目標食物：\(request.recognizedFoodName)")
                print("🥬 可用食材：\(request.recognizedIngredients.joined(separator: ", "))")
            }
        } catch {
            print("❌ 辨識食物食譜請求編碼失敗：\(error)")
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 無效的伺服器回應")
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ HTTP 錯誤：\(httpResponse.statusCode)")
            // 如果專用API還沒有，回退到一般的食譜生成
            if httpResponse.statusCode == 404 {
                print("⚠️ 專用API不存在，使用一般食譜生成作為備用方案")
                return try await generateRecipeUsingFallback(request: request)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(SuggestRecipeResponse.self, from: data)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ AI 回傳辨識食物食譜：\n\(jsonString)")
                print("🍽️ 生成食譜：\(decoded.dish_name)")
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

    // MARK: - 備用方案：使用一般食譜生成方式
    private static func generateRecipeUsingFallback(request: RecognizedFoodRecipeRequest) async throws -> SuggestRecipeResponse {
        print("🔄 使用備用方案生成 \(request.recognizedFoodName) 的食譜")

        let fallbackRequest = GenerateRecipeByNameRequest(
            dish_name: request.recognizedFoodName,
            preferred_ingredients: request.recognizedIngredients,
            excluded_ingredients: [],
            preferred_equipment: request.recognizedEquipment,
            preference: GenerateRecipeByNameRequest.GeneratePreference(
                cooking_method: "製作 \(request.recognizedFoodName)",
                doneness: nil,
                serving_size: "\(request.servings)人份"
            )
        )

        return try await generateRecipeByName(using: fallbackRequest)
    }

    // MARK: - 食譜生成 async 函式
    static func generateRecipe(using request: SuggestRecipeRequest) async throws -> SuggestRecipeResponse {
        let preferredIngredients = request.available_ingredients
            .map { $0.name }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let preferredEquipment = request.available_equipment
            .map { $0.name }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let excludedIngredients = request.preference.dietary_restrictions

        let cookingMethod = request.preference.cooking_method == "一般烹調" ? nil : request.preference.cooking_method

        let derivedDishName = deriveDishName(from: request)

        let generateRequest = GenerateRecipeByNameRequest(
            dish_name: derivedDishName,
            preferred_ingredients: preferredIngredients,
            excluded_ingredients: excludedIngredients,
            preferred_equipment: preferredEquipment,
            preference: GenerateRecipeByNameRequest.GeneratePreference(
                cooking_method: cookingMethod,
                doneness: nil,
                serving_size: request.preference.serving_size
            )
        )

        print("🛠️ 轉換食譜請求 -> 目標菜名：\(generateRequest.dish_name)")

        if let description = request.preference.recipe_description,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sanitizedDescription = stripCacheBusterSuffix(description).trimmingCharacters(in: extendedWhitespaces)
            if !sanitizedDescription.isEmpty {
                print("📝 使用者需求描述：\(sanitizedDescription)")
            }
        }

        return try await generateRecipeByName(using: generateRequest)
    }

    /// 根據使用者的偏好與辨識結果，推導最適合作為生成請求的菜名。
    ///
    /// 優先順序如下：
    /// 1. 使用者在偏好中輸入的食譜描述。
    /// 2. 從「製作 XXX」這類烹飪方式文字中提取的辨識菜名。
    /// 3. 以烹調方式與第一個主要食材組合出合理的菜名，若都缺少則使用預設文案。
    private static func deriveDishName(from request: SuggestRecipeRequest) -> String {
        if let rawDescription = request.preference.recipe_description?.trimmingCharacters(in: extendedWhitespaces),
           !rawDescription.isEmpty {
            let cleanedDescription = stripCacheBusterSuffix(rawDescription).trimmingCharacters(in: extendedWhitespaces)
            if !cleanedDescription.isEmpty {
                return cleanedDescription
            }
        }

        let mainIngredient = request.available_ingredients
            .map { trimExtendedWhitespaces($0.name) }
            .first { !$0.isEmpty }

        let method = trimExtendedWhitespaces(request.preference.cooking_method)

        if let recognizedDishName = extractRecognizedDishName(from: method, mainIngredient: mainIngredient) {
            return recognizedDishName
        }

        switch (method.isEmpty || method == "一般烹調", mainIngredient) {
        case (false, .some(let ingredient)):
            return "\(method)\(ingredient)"
        case (false, .none):
            return method
        case (true, .some(let ingredient)):
            return "\(ingredient)創意料理"
        default:
            return "AI 創意料理"
        }
    }

    private static let extendedWhitespaces: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "\u{3000}") // 全形空白
        return set
    }()

    private static func trimExtendedWhitespaces(_ string: String) -> String {
        string.trimmingCharacters(in: extendedWhitespaces)
    }

    private static func stripCacheBusterSuffix(_ string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\s*\\[[0-9]+\\]\\s*$", options: []) else {
            return string
        }

        var result = string
        while true {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: range) else {
                break
            }
            if let swiftRange = Range(match.range, in: result) {
                result.removeSubrange(swiftRange)
            } else {
                break
            }
        }
        return result
    }

    private static func extractRecognizedDishName(from method: String, mainIngredient: String?) -> String? {
        let trimmedMethod = trimExtendedWhitespaces(method)
        guard !trimmedMethod.isEmpty else { return nil }

        let pattern = "^製作[\\s\u{3000}:：-]*([^\\s].*)$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(trimmedMethod.startIndex..<trimmedMethod.endIndex, in: trimmedMethod)

        guard let match = regex.firstMatch(in: trimmedMethod, options: [], range: range),
              match.numberOfRanges >= 2,
              let capturedRange = Range(match.range(at: 1), in: trimmedMethod) else {
            return nil
        }

        let recognizedName = trimExtendedWhitespaces(String(trimmedMethod[capturedRange]))

        guard !recognizedName.isEmpty else { return nil }

        return recognizedName
    }
    // MARK: - 食物辨識 async 函式
    static func recognizeFood(using request: FoodRecognitionRequest) async throws -> FoodRecognitionResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/recipe/food") else {
            print("❌ 無效的食物辨識 URL")
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0 // 設定 30 秒超時

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData

            let requestInfo = """
            🟢 發送食物辨識請求：
            描述提示：\(request.descriptionHint)
            圖片大小：\(request.image.count) 字元
            """
            print(requestInfo)
        } catch {
            print("❌ 食物辨識請求編碼失敗：\(error)")
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 食物辨識：無效的伺服器回應")
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ 食物辨識：HTTP 錯誤：\(httpResponse.statusCode)")
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(FoodRecognitionResponse.self, from: data)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ AI 回傳食物辨識結果：\n\(jsonString)")
                print("📝 辨識摘要：\(decoded.summary)")
                print("🍽️ 辨識出 \(decoded.recognizedFoods.count) 種食物")
            }
            return decoded
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("🔴 食物辨識 AI 回傳原始資料：\n\(raw)")
            }
            print("❌ 食物辨識解碼失敗：\(error)")
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

// MARK: - 依名稱/偏好生成食譜請求資料模型
struct GenerateRecipeByNameRequest: Codable {
    let dish_name: String                      // 菜名（如「番茄炒蛋」）
    let preferred_ingredients: [String]        // 偏好的食材清單
    let excluded_ingredients: [String]         // 排除的食材清單
    let preferred_equipment: [String]          // 偏好的器具清單
    let preference: GeneratePreference         // 烹飪偏好設定

    struct GeneratePreference: Codable {
        let cooking_method: String?            // 烹飪方式（如「炒」）
        let doneness: String?                  // 熟度（如「全熟」）
        let serving_size: String               // 份量（如「2人份」）
    }
}

// MARK: - 辨識食物食譜請求資料模型（舊的，保留向後兼容）
struct RecognizedFoodRecipeRequest: Codable {
    let recognizedFoodName: String        // 辨識出的食物名稱（如「炒飯」）
    let recognizedIngredients: [String]   // 辨識出的食材清單
    let recognizedEquipment: [String]     // 辨識出的器具清單
    let confidence: Double?               // 辨識信心度
    let servings: Int                     // 預期份量

    enum CodingKeys: String, CodingKey {
        case recognizedFoodName = "recognized_food_name"
        case recognizedIngredients = "recognized_ingredients"
        case recognizedEquipment = "recognized_equipment"
        case confidence
        case servings
    }

    init(recognizedFoodName: String,
         recognizedIngredients: [String],
         recognizedEquipment: [String] = [],
         confidence: Double? = nil,
         servings: Int = 2) {
        self.recognizedFoodName = recognizedFoodName
        self.recognizedIngredients = recognizedIngredients
        self.recognizedEquipment = recognizedEquipment
        self.confidence = confidence
        self.servings = servings
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
