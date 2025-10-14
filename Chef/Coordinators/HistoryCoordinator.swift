//
//  HistoryCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/8.
//

import UIKit
import SwiftUI

@MainActor
final class HistoryCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: MainTabCoordinator?
    
    init(navigationController: UINavigationController, parentCoordinator: MainTabCoordinator? = nil) {
        self.navigationController = navigationController
        self.parentCoordinator = parentCoordinator
    }
    
    func start() {
        let viewModel = HistoryViewModel()
        
        // 設置回調
        viewModel.onReuseRecipe = { [weak self] history in
            self?.reuseRecipe(history)
        }
        
        viewModel.onReuseFoodRecognition = { [weak self] history in
            self?.reuseFoodRecognition(history)
        }
        
        viewModel.onReuseIngredientRecognition = { [weak self] history in
            self?.reuseIngredientRecognition(history)
        }
        
        let view = HistoryView(viewModel: viewModel)
        let page = UIHostingController(rootView: view)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.pushViewController(page, animated: false)
    }
    
    // MARK: - Navigation Methods
    
    /// 再次使用食譜（直接顯示食譜詳情頁面）
    private func reuseRecipe(_ history: RecipeHistory) {
        print("♻️ 再次使用食譜: \(history.displayName)")
        
        // 轉換為 RecipeRecommendationResponse
        let response = RecipeRecommendationResponse(
            dishName: history.response.dish_name,
            dishDescription: history.response.dish_description,
            ingredients: history.response.ingredients,
            equipment: history.response.equipment,
            recipe: history.response.recipe
        )
        
        // 顯示食譜詳情頁面
        showRecipeDetail(response)
    }
    
    /// 再次使用食物辨識（切換到辨識 Tab 並顯示結果）
    private func reuseFoodRecognition(_ history: FoodRecognitionHistory) {
        print("♻️ 再次使用食物辨識: \(history.displayName)")
        
        // 切換到辨識 Tab
        parentCoordinator?.tabBarController.selectedIndex = 1
        
        // 發送通知顯示結果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowFoodRecognitionHistory"),
                object: nil,
                userInfo: ["response": history.response]
            )
        }
    }
    
    /// 再次使用食材辨識（切換到推薦 Tab 並預填）
    private func reuseIngredientRecognition(_ history: IngredientRecognitionHistory) {
        print("♻️ 再次使用食材辨識: \(history.displayName)")
        
        // 切換到推薦 Tab
        parentCoordinator?.tabBarController.selectedIndex = 2
        
        // 發送通知預填資料
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: NSNotification.Name("PrefillIngredientRecognition"),
                object: nil,
                userInfo: [
                    "ingredients": history.response.ingredients.map { $0.name },
                    "equipment": history.response.equipment.map { $0.name }
                ]
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 顯示食譜詳情頁面
    private func showRecipeDetail(_ response: RecipeRecommendationResponse) {
        let detailView = RecipeDetailView(
            dishName: response.dishName,
            dishDescription: response.dishDescription,
            ingredients: response.ingredients,
            equipment: response.equipment,
            recipeSteps: response.recipe,
            showARButton: true,
            showNavigationBar: false,  // 使用系統導航欄，確保從烹飪頁面返回時有返回按鈕
            onStartCooking: { [weak self] in
                print("🍳 從歷史記錄開始烹飪")
                self?.startARCooking(with: response.recipe, dishName: response.dishName)
            },
            onBack: { [weak self] in
                self?.navigationController.popViewController(animated: true)
            },
            onFavorite: {
                print("⭐ 收藏食譜")
            }
        )
        
        let hostingController = UIHostingController(rootView: detailView)
        hostingController.title = response.dishName
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    /// 開始 AR 烹飪（公開給 IngredientConfirmationView 使用）
    func startARCooking(with steps: [RecipeStep], dishName: String = "料理") {
        print("🍳 開始 AR 烹飪: \(dishName)")
        
        let recipeContext = CookQARecipeContext(
            dishName: dishName,
            dishDescription: "",
            ingredients: [],
            equipment: [],
            recipe: steps
        )
        
        let coordinator = CookCoordinator(
            navigationController: navigationController,
            parentCoordinator: self
        )
        
        addChildCoordinator(coordinator)
        coordinator.start(
            with: steps,
            dishName: dishName,
            recipeContext: recipeContext
        )
    }
    
}

