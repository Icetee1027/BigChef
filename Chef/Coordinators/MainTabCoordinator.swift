//
//  MainTabCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/3.
//

import UIKit
//import SwiftUICore
import SwiftUI

@MainActor
final class MainTabCoordinator: Coordinator, ObservableObject {

    // MARK: - Properties
    var childCoordinators: [Coordinator] = []
    /// 提供給 AppCoordinator 當 rootViewController

    var navigationController: UINavigationController
    weak var parentCoordinator: AppCoordinator?
    let authViewModel: AuthViewModel

    // 每個 tab 的獨立 NavigationController
    var homeNavController: UINavigationController!
    var foodRecognitionNavController: UINavigationController!
    var recipeRecommendationNavController: UINavigationController!
    var historyNavController: UINavigationController!
    var favoritesNavController: UINavigationController!
    var settingsNavController: UINavigationController!

    var tabBarController: UITabBarController!

    init(navigationController: UINavigationController, parentCoordinator: AppCoordinator? = nil, authViewModel: AuthViewModel) {
        self.navigationController = navigationController
        self.parentCoordinator = parentCoordinator
        self.authViewModel = authViewModel
    }

    // MARK: - Public
    func start() {
        // 創建獨立的 NavigationController 給每個 tab
        homeNavController = UINavigationController()
        foodRecognitionNavController = UINavigationController()
        recipeRecommendationNavController = UINavigationController()
        historyNavController = UINavigationController()
        favoritesNavController = UINavigationController()
        settingsNavController = UINavigationController()

        // 創建每個 tab 的 root view
        let homeView = HomeTabView(coordinator: self)
        let homeVC = UIHostingController(rootView: homeView)
        homeVC.tabBarItem = UITabBarItem(title: "首頁", image: UIImage(systemName: "house.fill"), tag: 0)
        homeNavController.setViewControllers([homeVC], animated: false)

        let foodRecognitionView = FoodRecognitionTabView(coordinator: self)
        let foodRecognitionVC = UIHostingController(rootView: foodRecognitionView)
        foodRecognitionVC.tabBarItem = UITabBarItem(title: "辨識", image: UIImage(systemName: "camera.viewfinder"), tag: 1)
        foodRecognitionNavController.setViewControllers([foodRecognitionVC], animated: false)

        let recipeRecommendationView = RecipeRecommendationTabView(coordinator: self)
        let recipeRecommendationVC = UIHostingController(rootView: recipeRecommendationView)
        recipeRecommendationVC.tabBarItem = UITabBarItem(title: "推薦", image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        recipeRecommendationNavController.setViewControllers([recipeRecommendationVC], animated: false)

        let historyCoordinator = HistoryCoordinator(navigationController: historyNavController, parentCoordinator: self)
        addChildCoordinator(historyCoordinator)
        historyCoordinator.start()
        historyNavController.tabBarItem = UITabBarItem(title: "歷史", image: UIImage(systemName: "clock.arrow.circlepath"), tag: 3)

        let favoritesView = FavoritesTabView(coordinator: self)
        let favoritesVC = UIHostingController(rootView: favoritesView)
        favoritesVC.tabBarItem = UITabBarItem(title: "收藏", image: UIImage(systemName: "heart.fill"), tag: 4)
        favoritesNavController.setViewControllers([favoritesVC], animated: false)

        let settingsView = SettingsView().environmentObject(authViewModel)
        let settingsVC = UIHostingController(rootView: settingsView)
        settingsVC.tabBarItem = UITabBarItem(title: "設定", image: UIImage(systemName: "gear"), tag: 5)
        settingsNavController.setViewControllers([settingsVC], animated: false)

        // 創建 TabBarController
        tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            homeNavController,
            foodRecognitionNavController,
            recipeRecommendationNavController,
            historyNavController,
            favoritesNavController,
            settingsNavController
        ]

        // 設置為主 navigationController 的根視圖
        navigationController.setViewControllers([tabBarController], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    // 取得當前 tab 的 NavigationController
    private func currentTabNavigationController() -> UINavigationController? {
        guard let selectedIndex = tabBarController?.selectedIndex else { return nil }
        switch selectedIndex {
        case 0: return homeNavController
        case 1: return foodRecognitionNavController
        case 2: return recipeRecommendationNavController
        case 3: return historyNavController
        case 4: return favoritesNavController
        case 5: return settingsNavController
        default: return nil
        }
    }
    
    // MARK: - Navigation Methods

    func showRecipeDetail(_ recipe: SuggestRecipeResponse) {
        guard let navController = currentTabNavigationController() else { return }
        let coordinator = RecipeCoordinator(navigationController: navController)
        addChildCoordinator(coordinator)
        coordinator.showRecipeDetail(recipe)
    }

    func showRecipeDetail(_ recipe: Recipe) {
        guard let navController = currentTabNavigationController() else { return }
        let coordinator = RecipeCoordinator(navigationController: navController)
        addChildCoordinator(coordinator)
        coordinator.showRecipeDetail(recipe)
    }

    func showCamera() {
        guard let navController = currentTabNavigationController() else { return }
        let coordinator = CameraCoordinator(navigationController: navController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }
    
    func handleLogout() {
        print("MainTabCoordinator: 開始處理登出")
        
        // 清除所有子協調器
        print("MainTabCoordinator: 清除子協調器")
        childCoordinators.removeAll()
        
        // 通知父協調器處理登出
        if let parentCoordinator = parentCoordinator {
            print("MainTabCoordinator: 找到父協調器，通知處理登出")
            parentCoordinator.handleLogout()
        } else {
            print("MainTabCoordinator: 錯誤 - 父協調器為空")
        }
    }
}

// MARK: - Tab Views

private struct HomeTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var homeCoordinator: HomeCoordinator?
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                HomeView(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        // 先創建 HomeCoordinator，使用 home tab 的 navigationController
                        let newHomeCoordinator = HomeCoordinator(
                            navigationController: coordinator.homeNavController,
                            parentCoordinator: coordinator,
                            authViewModel: coordinator.authViewModel
                        )
                        coordinator.addChildCoordinator(newHomeCoordinator)
                        self.homeCoordinator = newHomeCoordinator

                        // 然後創建 ViewModel 並設置回調
                        let newViewModel = HomeViewModel(authViewModel: coordinator.authViewModel)
                        newViewModel.onSelectDish = { [weak newHomeCoordinator] dish in
                            newHomeCoordinator?.showDishDetail(dish)
                        }
                        newViewModel.onSelectRecipe = { [weak newHomeCoordinator] recipe in
                            newHomeCoordinator?.showRecipeDetail(recipe)
                        }
                        newViewModel.onRequestLogout = { [weak newHomeCoordinator] in
                            newHomeCoordinator?.handleLogout()
                        }
                        newViewModel.onShowAllRecipes = { [weak newHomeCoordinator] section, recipes in
                            newHomeCoordinator?.showAllRecipes(section: section, initialRecipes: recipes)
                        }
                        self.viewModel = newViewModel
                    }
            }
        }
    }
}

private struct FoodRecognitionTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var foodRecognitionCoordinator: FoodRecognitionCoordinator?
    @State private var viewModel: FoodRecognitionViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel, let coordinator = foodRecognitionCoordinator {
                FoodRecognitionView(viewModel: viewModel)
                    .environmentObject(coordinator)
            } else {
                ProgressView()
                    .onAppear {
                        let newFoodRecognitionCoordinator = FoodRecognitionCoordinator(
                            navigationController: coordinator.foodRecognitionNavController,
                            parentCoordinator: coordinator
                        )
                        coordinator.addChildCoordinator(newFoodRecognitionCoordinator)
                        self.foodRecognitionCoordinator = newFoodRecognitionCoordinator

                        let newViewModel = FoodRecognitionViewModel()
                        self.viewModel = newViewModel
                    }
            }
        }
    }
}

private struct RecipeRecommendationTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var recipeRecommendationCoordinator: RecipeRecommendationCoordinator?
    @State private var viewModel: RecipeRecommendationViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel, let coordinator = recipeRecommendationCoordinator {
                RecipeRecommendationView(viewModel: viewModel, coordinator: coordinator)
            } else {
                ProgressView()
                    .onAppear {
                        let newRecipeRecommendationCoordinator = RecipeRecommendationCoordinator(
                            navigationController: coordinator.recipeRecommendationNavController,
                            parentCoordinator: coordinator
                        )
                        coordinator.addChildCoordinator(newRecipeRecommendationCoordinator)
                        self.recipeRecommendationCoordinator = newRecipeRecommendationCoordinator

                        let newViewModel = RecipeRecommendationViewModel()
                        self.viewModel = newViewModel
                    }
            }
        }
    }
}


private struct FavoritesTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var viewModel: FavoritesViewModel?

    var body: some View {
        VStack {
            if let viewModel = viewModel {
                FavoritesView(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        let newViewModel = FavoritesViewModel(authViewModel: coordinator.authViewModel)
                        newViewModel.onSelectDish = { dish in
                            // Convert Dish to Recipe for navigation
                            let recipe = Recipe.createFromDish(dish)
                            coordinator.showRecipeDetail(recipe)
                        }
                        newViewModel.onSelectRecipe = { recipe in
                            coordinator.showRecipeDetail(recipe)
                        }
                        newViewModel.onRequestLogin = {
                            // TODO: Navigate to login screen
                            print("FavoritesTabView: 請求導航到登入頁面")
                        }
                        self.viewModel = newViewModel
                    }
            }
        }
    }
}
