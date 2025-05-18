import Foundation
import SwiftUI

@MainActor
final class ScanningViewModel: ObservableObject {
    // MARK: - UI State
    @Published var isLoading = false
    @Published var isShowingImagePicker = false
    @Published var isShowingImagePreview = false
    @Published var selectedImage: UIImage?
    @Published var descriptionHint = ""
    
    // MARK: - Data State
    @Published var equipment: [Equipment] = []
    @Published var ingredients: [Ingredient] = []
    @Published var preference: Preference = Preference(
        cooking_method: "一般烹調",  // 預設值
        dietary_restrictions: [],
        serving_size: "1人份"      // 預設值
    )

    // MARK: - Callbacks
    var onEquipmentScanRequested: (() -> Void)?
    var onRecipeGenerated: ((SuggestRecipeResponse) -> Void)?
    var onScanCompleted: ((ScanImageResponse, String) -> Void)?
    var onNavigateToRecipe: ((SuggestRecipeResponse) -> Void)?
    
    // MARK: - Public Methods
    
    /// 移除設備
    func removeEquipment(_ equipment: Equipment) {
        self.equipment.removeAll { $0.id == equipment.id }
    }
    
    /// 移除食材
    func removeIngredient(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
    }
    
    /// 更新或新增食材
    func upsertIngredient(_ new: Ingredient) {
        if let idx = ingredients.firstIndex(where: { $0.id == new.id }) {
            ingredients[idx] = new
        } else {
            ingredients.append(new)
        }
    }
    
    /// 更新或新增設備
    func upsertEquipment(_ new: Equipment) {
        if let idx = equipment.firstIndex(where: { $0.id == new.id }) {
            equipment[idx] = new
        } else {
            equipment.append(new)
        }
    }

    /// 產生食譜
    func generateRecipe(with preference: Preference) async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // 更新偏好設定
        self.preference = Preference(
            cooking_method: preference.cooking_method.isEmpty ? "一般烹調" : preference.cooking_method,
            dietary_restrictions: preference.dietary_restrictions,
            serving_size: preference.serving_size.isEmpty ? "1人份" : preference.serving_size
        )
        
        let request = SuggestRecipeRequest(
            available_ingredients: ingredients,
            available_equipment: equipment,
            preference: self.preference
        )

        do {
            let response = try await RecipeService.generateRecipe(using: request)
            print("✅ 成功解析 JSON，菜名：\(response.dish_name)")
            onRecipeGenerated?(response)
            onNavigateToRecipe?(response)
        } catch {
            print("❌ 錯誤：\(error.localizedDescription)")
        }
    }
    
    /// 掃描圖片
    func scanImage(request: ScanImageRequest) async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await RecipeService.scanImageForIngredients(using: request)
            print("✅ 掃描成功，摘要：\(response.summary)")
            onScanCompleted?(response, response.summary)
        } catch {
            print("❌ 掃描失敗：\(error.localizedDescription)")
        }
    }

    /// 處理選擇的圖片
    func handleSelectedImage(_ image: UIImage?) {
        selectedImage = image
        if image != nil {
            isShowingImagePreview = true
        }
    }
}
