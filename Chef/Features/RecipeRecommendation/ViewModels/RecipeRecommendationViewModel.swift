//
//  RecipeRecommendationViewModel.swift
//  ChefHelper
//
//  Created by Claude on 2025/9/22.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class RecipeRecommendationViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var state: RecipeRecommendationStatus = .idle
    @Published var availableIngredients: [AvailableIngredient] = []
    @Published var availableEquipment: [AvailableEquipment] = []
    @Published var preference: RecommendationPreference
    @Published var recommendationResult: RecipeRecommendationResponse?
    @Published var errorMessage: String?
    @Published var retryCount = 0
    @Published var isFormValid: Bool = false
    @Published var validationErrors: [String] = []

    // MARK: - New Properties for Food Recognition
    @Published var recognizedFoodName: String? = nil  // 辨識出的食物名稱

    // MARK: - Private Properties
    private let recommendationService: RecipeRecommendationService
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    private let maxRetryCount = 3

    // MARK: - Computed Properties

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    var hasResult: Bool {
        if case .success = state { return true }
        return false
    }

    var canRequestRecommendation: Bool {
        switch state {
        case .configuring, .idle:
            return isFormValid
        case .error:
            return isFormValid
        case .loading:
            return false
        case .success:
            return true // Allow re-recommendation from success state
        }
    }

    var canRetry: Bool {
        if case .error(let error) = state {
            return error.isRetryable && retryCount < maxRetryCount
        }
        return false
    }

    var currentError: RecipeRecommendationError? {
        if case .error(let error) = state {
            return error
        }
        return nil
    }

    var ingredientTypes: [String] {
        ["主食", "蔬菜", "肉類", "蛋類", "海鮮", "調料", "其他"]
    }

    var equipmentTypes: [String] {
        ["鍋具", "刀具", "電器", "餐具", "其他"]
    }

    var cookingMethods: [String] {
        ["一般烹調", "煎", "炒", "煮", "蒸", "炸", "烤", "燉", "涼拌"]
    }

    var dietaryRestrictions: [String] {
        ["無", "素食", "純素", "無麩質", "無乳製品", "低糖", "低鈉", "低脂"]
    }

    var servingSizes: [String] {
        ["1人份", "2人份", "3人份", "4人份", "5人份", "6人份以上"]
    }

    // MARK: - Initializer

    init(recommendationService: RecipeRecommendationService = RecipeRecommendationService()) {
        self.recommendationService = recommendationService
        self.preference = RecommendationPreference(
            cookingMethod: "一般烹調",
            dietaryRestrictions: [],
            servingSize: "1人份",
            recipeDescription: nil
        )
        setupObservations()
        setupNotificationObservers()
    }

    deinit {
        currentTask?.cancel()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // 監聽從食材辨識預填
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PrefillIngredientRecognition"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let ingredients = userInfo["ingredients"] as? [String],
                  let equipment = userInfo["equipment"] as? [String] else {
                return
            }
            
            Task { @MainActor in
                self.prefillFromRecognition(ingredients: ingredients, equipment: equipment, recognizedFoodName: nil)
            }
        }
    }

    // MARK: - Public Methods - Data Prefilling

    /// 預填食材和器具資料（來自食物辨識）
    func prefillFromRecognition(ingredients: [String], equipment: [String] = [], recognizedFoodName: String? = nil) {
        print("🔄 RecipeRecommendationViewModel: 預填辨識結果")
        print("  辨識食物：\(recognizedFoodName ?? "基於食材推薦")")
        print("  食材：\(ingredients)")
        print("  器具：\(equipment)")

        // 設置辨識食物名稱
        self.recognizedFoodName = recognizedFoodName

        // 轉換食材
        self.availableIngredients = ingredients.map { name in
            AvailableIngredient(
                name: name,
                type: "食材",
                amount: "適量",
                unit: "",
                preparation: ""
            )
        }

        // 轉換器具
        self.availableEquipment = equipment.map { name in
            AvailableEquipment(
                name: name,
                type: "器具",
                size: "",
                material: "",
                powerSource: ""
            )
        }

        // 根據辨識食物調整偏好設定
        if let foodName = recognizedFoodName {
            preference = RecommendationPreference(
                cookingMethod: "製作 \(foodName)",
                dietaryRestrictions: preference.dietaryRestrictions,
                servingSize: preference.servingSize,
                recipeDescription: preference.recipeDescription
            )
        }

        // 更新表單驗證狀態
        isFormValid = validateForm()
    }

    // MARK: - Private Methods - New API Integration

    /// 基於辨識食物生成製作食譜
    private func generateRecipeForRecognizedFood(
        foodName: String,
        ingredients: [String],
        equipment: [String]
    ) async throws -> RecipeRecommendationResponse {

        // 使用新的 /api/v1/recipe/generate 端點
        let request = GenerateRecipeByNameRequest(
            dish_name: foodName,
            preferred_ingredients: ingredients,
            excluded_ingredients: [],  // 目前沒有排除的食材
            preferred_equipment: equipment,
            preference: GenerateRecipeByNameRequest.GeneratePreference(
                cooking_method: preference.cookingMethod == "一般烹調" ? nil : preference.cookingMethod,
                doneness: nil,  // 目前沒有熟度設定
                serving_size: preference.servingSize ?? "2人份"
            )
        )

        // 🔍 檢查快取
        let requestHash = RecipeHistoryService.shared.calculateRequestHash(request)
        if let cachedHistory = RecipeHistoryService.shared.findByHash(requestHash) {
            print("✅ 從快取載入食物生成食譜 - \(cachedHistory.response.dish_name)")
            print("⏱️ 上次使用：\(formatTimeSince(cachedHistory.lastUsedAt ?? cachedHistory.timestamp))")
            
            // 更新使用次數
            RecipeHistoryService.shared.incrementUsage(id: cachedHistory.id)
            
            // 轉換回應格式
            var cachedResponse = RecipeRecommendationResponse(
                dishName: cachedHistory.response.dish_name,
                dishDescription: cachedHistory.response.dish_description,
                ingredients: cachedHistory.response.ingredients,
                equipment: cachedHistory.response.equipment,
                recipe: cachedHistory.response.recipe
            )
            
            // 添加快取標記
            cachedResponse.isFromCache = true
            cachedResponse.cacheTimestamp = cachedHistory.timestamp
            cachedResponse.historyId = cachedHistory.id
            
            return cachedResponse
        }

        // 調用新的 RecipeService API
        let recipeResponse = try await RecipeService.generateRecipeByName(using: request)

        // 💾 儲存到歷史記錄（只有成功的回應才儲存）
        if let history = RecipeHistoryService.shared.saveFromFoodRecipe(
            request: request,
            response: recipeResponse
        ) {
            var savedResponse = RecipeRecommendationResponse(
                dishName: recipeResponse.dish_name,
                dishDescription: recipeResponse.dish_description,
                ingredients: recipeResponse.ingredients,
                equipment: recipeResponse.equipment,
                recipe: recipeResponse.recipe
            )
            savedResponse.historyId = history.id
            return savedResponse
        }

        // 轉換為 RecipeRecommendationResponse
        return RecipeRecommendationResponse(
            dishName: recipeResponse.dish_name,
            dishDescription: recipeResponse.dish_description,
            ingredients: recipeResponse.ingredients,
            equipment: recipeResponse.equipment,
            recipe: recipeResponse.recipe
        )
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

    /// 從份量字串中提取數字
    private func extractServingNumber(from servingString: String) -> Int {
        let numberRegex = try? NSRegularExpression(pattern: "\\d+", options: [])
        let range = NSRange(location: 0, length: servingString.utf16.count)

        if let match = numberRegex?.firstMatch(in: servingString, options: [], range: range) {
            let numberString = (servingString as NSString).substring(with: match.range)
            return Int(numberString) ?? 2
        }
        return 2
    }

    // MARK: - Public Methods - Task Management

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil

        if case .loading = state {
            updateState(.configuring)
        }
    }

    // MARK: - Private Methods

    private func setupObservations() {
        // 監控食材和設備變化來更新狀態和驗證表單
        Publishers.CombineLatest3($availableIngredients, $availableEquipment, $preference)
            .sink { [weak self] ingredients, equipment, preference in
                self?.updateStateBasedOnInput()
                self?.validateFormData()
            }
            .store(in: &cancellables)
    }

    private func updateStateBasedOnInput() {
        if availableIngredients.isEmpty {
            updateState(.idle)
        } else {
            if case .idle = state {
                updateState(.configuring)
            }
        }
    }

    private func updateState(_ newState: RecipeRecommendationStatus) {
        state = newState

        // 清除錯誤訊息（除非是錯誤狀態）
        if case .error(let error) = newState {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = nil
        }
    }

    private func validateFormData() {
        validationErrors.removeAll()

        // 移除所有驗證檢查，直接設定為有效
        isFormValid = true
    }

    private func validateForm() -> Bool {
        validateFormData()
        return isFormValid
    }

    private func handleRecommendationError(_ error: Error) {
        retryCount += 1

        let recommendationError: RecipeRecommendationError

        if let recError = error as? RecipeRecommendationError {
            recommendationError = recError
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                recommendationError = .networkError("請檢查網路連線")
            case .timedOut:
                recommendationError = .networkError("請求超時，請稍後再試")
            case .cannotFindHost:
                recommendationError = .networkError("無法連接到伺服器")
            default:
                recommendationError = .networkError("網路錯誤：\(urlError.localizedDescription)")
            }
        } else {
            recommendationError = .networkError("未知錯誤：\(error.localizedDescription)")
        }

        updateState(.error(recommendationError))
    }

    // MARK: - Public Methods - 食材管理

    func addIngredient(_ ingredient: AvailableIngredient) {
        withAnimation(.easeInOut) {
            availableIngredients.append(ingredient)
        }
        print("🥬 RecipeRecommendationViewModel: 新增食材 - \(ingredient.name)")
    }

    func removeIngredient(at index: Int) {
        guard index < availableIngredients.count else { return }
        let removedIngredient = availableIngredients[index]
        _ = withAnimation(.easeInOut) {
            availableIngredients.remove(at: index)
        }
        print("🗑️ RecipeRecommendationViewModel: 移除食材 - \(removedIngredient.name)")
    }

    func updateIngredient(at index: Int, with ingredient: AvailableIngredient) {
        guard index < availableIngredients.count else { return }
        availableIngredients[index] = ingredient
        print("✏️ RecipeRecommendationViewModel: 更新食材 - \(ingredient.name)")
    }

    func createEmptyIngredient() -> AvailableIngredient {
        return AvailableIngredient(
            name: "",
            type: ingredientTypes.first ?? "其他",
            amount: "適量",
            unit: "",
            preparation: ""
        )
    }

    // MARK: - Public Methods - 設備管理

    func addEquipment(_ equipment: AvailableEquipment) {
        withAnimation(.easeInOut) {
            availableEquipment.append(equipment)
        }
        print("🔧 RecipeRecommendationViewModel: 新增設備 - \(equipment.name)")
    }

    func removeEquipment(at index: Int) {
        guard index < availableEquipment.count else { return }
        let removedEquipment = availableEquipment[index]
        _ = withAnimation(.easeInOut) {
            availableEquipment.remove(at: index)
        }
        print("🗑️ RecipeRecommendationViewModel: 移除設備 - \(removedEquipment.name)")
    }

    func updateEquipment(at index: Int, with equipment: AvailableEquipment) {
        guard index < availableEquipment.count else { return }
        availableEquipment[index] = equipment
        print("✏️ RecipeRecommendationViewModel: 更新設備 - \(equipment.name)")
    }

    func createEmptyEquipment() -> AvailableEquipment {
        return AvailableEquipment(
            name: "",
            type: equipmentTypes.first ?? "其他",
            size: "中等",
            material: "",
            powerSource: ""
        )
    }

    // MARK: - Public Methods - 偏好設定管理

    func updatePreference(_ newPreference: RecommendationPreference) {
        // 標準化烹飪方式
        let normalizedCookingMethod = normalizeCookingMethod(newPreference.cookingMethod)
        
        self.preference = RecommendationPreference(
            cookingMethod: normalizedCookingMethod,
            dietaryRestrictions: newPreference.dietaryRestrictions,
            servingSize: newPreference.servingSize,
            recipeDescription: newPreference.recipeDescription
        )
        isFormValid = validateForm()
    }
    
    /// 標準化烹飪方式（確保在選項列表中）
    private func normalizeCookingMethod(_ method: String?) -> String {
        guard let method = method, !method.isEmpty else {
            return "一般烹調"
        }
        
        // 如果是 "製作 XXX" 格式，使用預設
        if method.hasPrefix("製作 ") {
            return "一般烹調"
        }
        
        // 如果在選項列表中，直接使用
        if cookingMethods.contains(method) {
            return method
        }
        
        // 否則使用預設
        return "一般烹調"
    }
    
    func updateCookingMethod(_ method: String) {
        preference = RecommendationPreference(
            cookingMethod: method,
            dietaryRestrictions: preference.dietaryRestrictions,
            servingSize: preference.servingSize,
            recipeDescription: preference.recipeDescription
        )
    }

    func updateDietaryRestrictions(_ restrictions: [String]) {
        preference = RecommendationPreference(
            cookingMethod: preference.cookingMethod,
            dietaryRestrictions: restrictions,
            servingSize: preference.servingSize,
            recipeDescription: preference.recipeDescription
        )
    }

    func updateServingSize(_ size: String) {
        preference = RecommendationPreference(
            cookingMethod: preference.cookingMethod,
            dietaryRestrictions: preference.dietaryRestrictions,
            servingSize: size,
            recipeDescription: preference.recipeDescription
        )
    }

    func updateRecipeDescription(_ description: String?) {
        preference = RecommendationPreference(
            cookingMethod: preference.cookingMethod,
            dietaryRestrictions: preference.dietaryRestrictions,
            servingSize: preference.servingSize,
            recipeDescription: description?.isEmpty == true ? nil : description
        )
    }

    // MARK: - Public Methods - 推薦流程

    func startRecommendation() async {
        // Cancel any existing request
        currentTask?.cancel()

        guard canRequestRecommendation else {
            print("❌ RecipeRecommendationViewModel: 無法開始推薦 - 表單驗證失敗")
            if !isFormValid {
                updateState(.error(.validationFailed("請檢查表單輸入")))
            }
            return
        }

        print("🍳 RecipeRecommendationViewModel: 開始食譜推薦")

        // 🧹 清除舊的推薦結果，釋放記憶體
        recommendationResult = nil

        updateState(.loading)
        if case .success = state {
            // Don't reset retry count if re-recommending from success state
        } else {
            retryCount = 0
        }

        currentTask = Task {
            do {
                let response: RecipeRecommendationResponse

                // 如果有辨識出的食物名稱，使用新的專用 API
                if let foodName = recognizedFoodName, !foodName.isEmpty {
                    print("🍽️ 使用辨識食物 API 生成 \(foodName) 的製作食譜")
                    response = try await generateRecipeForRecognizedFood(
                        foodName: foodName,
                        ingredients: availableIngredients.map { $0.name },
                        equipment: availableEquipment.map { $0.name }
                    )
                } else {
                    print("🥬 使用一般推薦 API 基於食材生成食譜")

                    // 使用正常的 preference，啟用本地快取機制
                    response = try await recommendationService.recommendRecipe(
                        ingredients: availableIngredients,
                        equipment: availableEquipment,
                        preference: preference
                    )
                }

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    recommendationResult = response
                    updateState(.success(response))
                    print("✅ RecipeRecommendationViewModel: 推薦成功")
                }

            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    print("❌ RecipeRecommendationViewModel: 推薦失敗 - \(error.localizedDescription)")
                    handleRecommendationError(error)
                }
            }
        }

        await currentTask?.value
        currentTask = nil
    }

    func retryRecommendation() async {
        guard canRetry else {
            print("❌ RecipeRecommendationViewModel: 無法重試推薦")
            return
        }

        print("🔄 RecipeRecommendationViewModel: 重試推薦 (第 \(retryCount + 1) 次)")
        await startRecommendation()
    }

    func resetToInitial() {
        print("🔄 RecipeRecommendationViewModel: 重置到初始狀態")
        availableIngredients.removeAll()
        availableEquipment.removeAll()
        preference = RecommendationPreference(
            cookingMethod: "一般烹調",
            dietaryRestrictions: [],
            servingSize: "1人份",
            recipeDescription: nil
        )
        recommendationResult = nil
        retryCount = 0
        updateState(.idle)
    }

    func resetToConfiguring() {
        print("🔄 RecipeRecommendationViewModel: 重新配置（清空所有）")
        availableIngredients.removeAll()
        availableEquipment.removeAll()
        recognizedFoodName = nil
        recommendationResult = nil
        retryCount = 0
        updateState(.idle)
    }

    func backToConfiguration() {
        print("🔄 RecipeRecommendationViewModel: 返回配置（保留食材）")
        // 只清除結果和錯誤狀態，保留食材和器具
        recommendationResult = nil
        retryCount = 0
        updateState(.configuring)
    }

    // MARK: - Private Helper Methods

    // createPreferenceWithCacheBuster 已移除，改用本地快取機制
}