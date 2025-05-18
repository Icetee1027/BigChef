////
////  RecipeCoordinator.swift
////  ChefHelper
////
////  Created by 陳泓齊 on 2025/5/4.
////

import SwiftUI

@MainActor
final class RecipeCoordinator: Coordinator, ObservableObject {
    
    /// 用來管理此協調器所啟動的子協調器們
    var childCoordinators: [Coordinator] = []
    
    /// UINavigationController 實例，負責畫面導航推疊
    var navigationController: UINavigationController
    
    /// 建構子，注入 UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    /// 啟動協調器，推入一個空的食譜視圖
    func start() {
        // 建立一個空的 SuggestRecipeResponse (食譜模型) 傳給 RecipeViewModel
        let viewModel = RecipeViewModel(response: SuggestRecipeResponse(
            dish_name: "",           // 空的菜名
            dish_description: "",    // 空的描述
            ingredients: [],         // 空食材列表
            equipment: [],           // 空設備列表
            recipe: []               // 空步驟列表
        ))
        // 利用私有方法推入 RecipeView
        pushRecipeView(with: viewModel)
    }
    
    /// 顯示特定食譜的詳細頁面
    /// - Parameter recipe: 要顯示的食譜資料
    func showRecipeDetail(_ recipe: SuggestRecipeResponse) {
        // 以傳入的食譜資料建立 ViewModel
        let viewModel = RecipeViewModel(response: recipe)
        
        // 設定點擊「開始烹飪」時的 callback
        viewModel.onCookRequested = { [weak self] in
            // 呼叫私有方法開始烹飪流程
            self?.startCooking(with: recipe.recipe)
        }
        
        // 推入 RecipeView
        pushRecipeView(with: viewModel)
    }
    
    /// 顯示食譜編輯頁面
    /// - Parameter recipe: 要編輯的食譜資料
    func showRecipeEdit(_ recipe: SuggestRecipeResponse) {
        // 直接用該食譜資料建立 ViewModel 並推入 RecipeView
        pushRecipeView(with: RecipeViewModel(response: recipe))
    }
    
    /// 顯示掃描頁面，啟動掃描協調器
    func showScanning() {
        let coordinator = ScanningCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator) // 加入子協調器管理陣列
        coordinator.start()              // 啟動掃描流程
    }
    
    /// 顯示相機頁面，啟動相機協調器
    func showCamera() {
        let coordinator = CameraCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator) // 加入子協調器管理陣列
        coordinator.start()              // 啟動相機流程
    }
    
    // MARK: - Private Helpers
    
    /// 私有方法：用指定的 ViewModel 建立 RecipeView，並推入導航堆疊
    /// - Parameter viewModel: RecipeViewModel 實例
    private func pushRecipeView(with viewModel: RecipeViewModel) {
        // 建立 RecipeView 並注入自己 (Coordinator) 作為 environmentObject，方便內部 View 操控導航
        let view = RecipeView(viewModel: viewModel)
            .environmentObject(self)
        
        // 使用 UIHostingController 封裝 SwiftUI View，搭配 UIKit 導航控制器使用
        let hostingController = UIHostingController(rootView: view)
        
        // 推入導航堆疊並顯示該頁面，animated: true 表示有動畫效果
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    /// 私有方法：開始烹飪流程，建立 CookCoordinator 並啟動
    /// - Parameter steps: 食譜步驟陣列
    private func startCooking(with steps: [RecipeStep]) {
        let coordinator = CookCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator) // 加入子協調器管理陣列
        coordinator.start(with: steps)   // 啟動烹飪流程並傳入步驟
    }
}
