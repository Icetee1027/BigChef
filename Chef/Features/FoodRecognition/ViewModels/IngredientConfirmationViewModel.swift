//
//  IngredientConfirmationViewModel.swift
//  ChefHelper
//
//  Created by Claude on 2025/9/27.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Recipe Generation State
enum RecipeGenerationState {
    case configuring        // 配置食材器具
    case loading           // 生成食譜中
    case success(RecipeRecommendationResponse)  // 生成成功
    case error(Error)      // 生成失敗
}

@MainActor
final class IngredientConfirmationViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var recognizedIngredients: [PossibleIngredient] = []
    @Published var recognizedEquipment: [PossibleEquipment] = []
    @Published var selectedIngredients: Set<String> = []
    @Published var selectedEquipment: Set<String> = []
    @Published var customIngredients: [String] = []
    @Published var customEquipment: [String] = []
    @Published var newIngredientName: String = ""
    @Published var newEquipmentName: String = ""
    @Published var isFormValid: Bool = false
    @Published var generationState: RecipeGenerationState = .configuring

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    private var recognizedFoodName: String?  // 儲存辨識出的食物名稱

    // MARK: - Computed Properties
    var totalSelectedIngredients: [String] {
        let recognized = selectedIngredients.map { $0 }
        return recognized + customIngredients
    }

    var totalSelectedEquipment: [String] {
        let recognized = selectedEquipment.map { $0 }
        return recognized + customEquipment
    }

    var canProceed: Bool {
        return !totalSelectedIngredients.isEmpty
    }

    // MARK: - Initializer
    init() {
        setupObservations()
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Public Methods

    func configure(with recognitionResult: FoodRecognitionResponse) {
        print("🔄 IngredientConfirmationViewModel: 配置辨識結果")

        // 重新進入調整頁面時，確保回到初始狀態
        currentTask?.cancel()
        currentTask = nil
        generationState = .configuring

        // 儲存辨識出的食物名稱
        recognizedFoodName = recognitionResult.recognizedFoods.first?.name

        // 從所有辨識出的食物中提取食材和器具
        recognizedIngredients = recognitionResult.recognizedFoods.flatMap { $0.possibleIngredients }
        recognizedEquipment = recognitionResult.recognizedFoods.flatMap { $0.possibleEquipment }

        // 預設選中所有辨識到的食材和器具
        selectedIngredients = Set(recognizedIngredients.map { $0.name })
        selectedEquipment = Set(recognizedEquipment.map { $0.name })

        // 清除先前的自訂項目與輸入內容，避免沿用舊資料
        customIngredients.removeAll()
        customEquipment.removeAll()
        newIngredientName = ""
        newEquipmentName = ""

        print("  辨識食物: \(recognizedFoodName ?? "未知")")
        print("  辨識食材: \(recognizedIngredients.map { $0.name })")
        print("  辨識器具: \(recognizedEquipment.map { $0.name })")

        validateForm()
    }

    func toggleIngredientSelection(_ ingredientName: String) {
        if selectedIngredients.contains(ingredientName) {
            selectedIngredients.remove(ingredientName)
        } else {
            selectedIngredients.insert(ingredientName)
        }
        print("🥬 切換食材選擇: \(ingredientName) - 已選擇: \(selectedIngredients.contains(ingredientName))")
    }

    func toggleEquipmentSelection(_ equipmentName: String) {
        if selectedEquipment.contains(equipmentName) {
            selectedEquipment.remove(equipmentName)
        } else {
            selectedEquipment.insert(equipmentName)
        }
        print("🔧 切換器具選擇: \(equipmentName) - 已選擇: \(selectedEquipment.contains(equipmentName))")
    }

    func addCustomIngredient() {
        let trimmedName = newIngredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // 檢查是否已存在
        guard !customIngredients.contains(trimmedName),
              !recognizedIngredients.contains(where: { $0.name == trimmedName }) else {
            print("❌ 食材已存在: \(trimmedName)")
            return
        }

        customIngredients.append(trimmedName)
        newIngredientName = ""
        print("➕ 新增自訂食材: \(trimmedName)")
    }

    func removeCustomIngredient(at index: Int) {
        guard index < customIngredients.count else { return }
        let removed = customIngredients.remove(at: index)
        print("➖ 移除自訂食材: \(removed)")
    }

    func addCustomEquipment() {
        let trimmedName = newEquipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // 檢查是否已存在
        guard !customEquipment.contains(trimmedName),
              !recognizedEquipment.contains(where: { $0.name == trimmedName }) else {
            print("❌ 器具已存在: \(trimmedName)")
            return
        }

        customEquipment.append(trimmedName)
        newEquipmentName = ""
        print("➕ 新增自訂器具: \(trimmedName)")
    }

    func removeCustomEquipment(at index: Int) {
        guard index < customEquipment.count else { return }
        let removed = customEquipment.remove(at: index)
        print("➖ 移除自訂器具: \(removed)")
    }

    func selectAllIngredients() {
        selectedIngredients = Set(recognizedIngredients.map { $0.name })
        print("✅ 選擇所有食材")
    }

    func deselectAllIngredients() {
        selectedIngredients.removeAll()
        print("❌ 取消選擇所有食材")
    }

    func selectAllEquipment() {
        selectedEquipment = Set(recognizedEquipment.map { $0.name })
        print("✅ 選擇所有器具")
    }

    func addScannedIngredient(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // 檢查是否已存在
        guard !customIngredients.contains(trimmedName),
              !recognizedIngredients.contains(where: { $0.name == trimmedName }) else {
            print("❌ 食材已存在: \(trimmedName)")
            return
        }

        customIngredients.append(trimmedName)
        print("➕ 新增掃描食材: \(trimmedName)")
    }

    func addScannedEquipment(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // 檢查是否已存在
        guard !customEquipment.contains(trimmedName),
              !recognizedEquipment.contains(where: { $0.name == trimmedName }) else {
            print("❌ 器具已存在: \(trimmedName)")
            return
        }

        customEquipment.append(trimmedName)
        print("➕ 新增掃描器具: \(trimmedName)")
    }

    func deselectAllEquipment() {
        selectedEquipment.removeAll()
        print("❌ 取消選擇所有器具")
    }

    // MARK: - Editing Methods

    func updateIngredientName(oldName: String, newName: String) {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty else { return }
        guard trimmedNewName != oldName else { return }

        // 檢查新名稱是否已存在
        let allIngredientNames = recognizedIngredients.map { $0.name } + customIngredients
        guard !allIngredientNames.contains(where: { $0 == trimmedNewName && $0 != oldName }) else {
            print("❌ 食材名稱已存在: \(trimmedNewName)")
            return
        }

        // 更新辨識到的食材
        if let index = recognizedIngredients.firstIndex(where: { $0.name == oldName }) {
            recognizedIngredients[index] = PossibleIngredient(name: trimmedNewName, type: recognizedIngredients[index].type)
            // 更新選擇狀態
            if selectedIngredients.contains(oldName) {
                selectedIngredients.remove(oldName)
                selectedIngredients.insert(trimmedNewName)
            }
            print("✏️ 更新辨識食材: \(oldName) -> \(trimmedNewName)")
        }
        // 更新自訂食材
        else if let index = customIngredients.firstIndex(of: oldName) {
            customIngredients[index] = trimmedNewName
            print("✏️ 更新自訂食材: \(oldName) -> \(trimmedNewName)")
        }
    }

    func updateEquipmentName(oldName: String, newName: String) {
        let trimmedNewName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewName.isEmpty else { return }
        guard trimmedNewName != oldName else { return }

        // 檢查新名稱是否已存在
        let allEquipmentNames = recognizedEquipment.map { $0.name } + customEquipment
        guard !allEquipmentNames.contains(where: { $0 == trimmedNewName && $0 != oldName }) else {
            print("❌ 器具名稱已存在: \(trimmedNewName)")
            return
        }

        // 更新辨識到的器具
        if let index = recognizedEquipment.firstIndex(where: { $0.name == oldName }) {
            recognizedEquipment[index] = PossibleEquipment(name: trimmedNewName, type: recognizedEquipment[index].type)
            // 更新選擇狀態
            if selectedEquipment.contains(oldName) {
                selectedEquipment.remove(oldName)
                selectedEquipment.insert(trimmedNewName)
            }
            print("✏️ 更新辨識器具: \(oldName) -> \(trimmedNewName)")
        }
        // 更新自訂器具
        else if let index = customEquipment.firstIndex(of: oldName) {
            customEquipment[index] = trimmedNewName
            print("✏️ 更新自訂器具: \(oldName) -> \(trimmedNewName)")
        }
    }

    func removeRecognizedIngredient(_ ingredientName: String) {
        if let index = recognizedIngredients.firstIndex(where: { $0.name == ingredientName }) {
            recognizedIngredients.remove(at: index)
            selectedIngredients.remove(ingredientName)
            print("🗑️ 移除辨識食材: \(ingredientName)")
        }
    }

    func removeRecognizedEquipment(_ equipmentName: String) {
        if let index = recognizedEquipment.firstIndex(where: { $0.name == equipmentName }) {
            recognizedEquipment.remove(at: index)
            selectedEquipment.remove(equipmentName)
            print("🗑️ 移除辨識器具: \(equipmentName)")
        }
    }

    // MARK: - Recipe Generation Methods

    /// 生成食譜
    func generateRecipe() async {
        print("🧑‍🍳 IngredientConfirmationViewModel: 開始生成食譜")

        generationState = .loading

        currentTask = Task {
            do {
                let service = RecipeRecommendationService()

                let availableIngredients = totalSelectedIngredients.map { ingredient in
                    AvailableIngredient(
                        name: ingredient,
                        type: "食材",
                        amount: "適量",
                        unit: "",
                        preparation: ""
                    )
                }

                let availableEquipment = totalSelectedEquipment.map { equip in
                    AvailableEquipment(
                        name: equip,
                        type: "器具",
                        size: "中等",
                        material: "",
                        powerSource: "無"
                    )
                }

                let preference = RecommendationPreference(
                    cookingMethod: recognizedFoodName.map { "製作 \($0)" },
                    dietaryRestrictions: [],
                    servingSize: "2人份",
                    recipeDescription: nil
                )

                print("  食材: \(totalSelectedIngredients)")
                print("  器具: \(totalSelectedEquipment)")
                print("  偏好: 製作 \(recognizedFoodName ?? "料理")")

                let result = try await service.recommendRecipe(
                    ingredients: availableIngredients,
                    equipment: availableEquipment,
                    preference: preference
                )

                await MainActor.run {
                    self.generationState = .success(result)
                    print("✅ 食譜生成成功: \(result.dishName)")
                }

            } catch {
                await MainActor.run {
                    self.generationState = .error(error)
                    print("❌ 食譜生成失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 取消當前生成任務
    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        generationState = .configuring
        print("🚫 取消食譜生成")
    }

    /// 返回配置狀態
    func backToConfiguration() {
        generationState = .configuring
        print("🔙 返回配置頁面")
    }

    /// 重試生成
    func retryGeneration() async {
        await generateRecipe()
    }

    // MARK: - Private Methods

    private func setupObservations() {
        Publishers.CombineLatest4($selectedIngredients, $selectedEquipment, $customIngredients, $customEquipment)
            .sink { [weak self] _, _, _, _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
    }

    private func validateForm() {
        isFormValid = canProceed
    }
}