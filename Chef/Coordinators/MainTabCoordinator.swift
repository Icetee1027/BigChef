import UIKit
import SwiftUI

/// 登入後的主流程協調器，控制主頁面 TabView（食譜、掃描、設定）
@MainActor
final class MainTabCoordinator: Coordinator, ObservableObject {

    // MARK: - Properties

    /// 子協調器列表，方便管理導航流程
    var childCoordinators: [Coordinator] = []

    /// 主要的 UINavigationController，放入 UIHostingController 作為 rootViewController
    var navigationController: UINavigationController

    /// 建構子，接收 UINavigationController
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // MARK: - Public Methods

    /// 啟動主頁面，建立 SwiftUI 的 TabView 並包進 UIHostingController
    func start() {
        // 建立三個主要的 Tab 畫面
        let tabView = TabView {
            // 食譜頁籤（用 NavigationStack 包裝）
            NavigationStack {
                RecipeTabView(coordinator: self)
            }
            .tabItem {
                Label("Recipes", systemImage: "book.fill")
            }

            // 掃描頁籤（用 NavigationStack 包裝）
            NavigationStack {
                ScanningTabView(coordinator: self)
            }
            .tabItem {
                Label("Scan", systemImage: "camera.fill")
            }

            // 設定頁籤
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }

        // 將 SwiftUI TabView 用 UIHostingController 包起來
        let hostingController = UIHostingController(rootView: tabView)
        // 設定 UINavigationController 的 rootViewController
        navigationController.setViewControllers([hostingController], animated: false)
    }

    // MARK: - Navigation Helpers

    /// 顯示食譜細節頁面
    func showRecipeDetail(_ recipe: SuggestRecipeResponse) {
        let coordinator = RecipeCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.showRecipeDetail(recipe)
    }

    /// 顯示掃描頁面
    func showScanning() {
        let coordinator = ScanningCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }

    /// 顯示相機頁面
    func showCamera() {
        let coordinator = CameraCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }
}

// MARK: - Tab View Components

/// Recipe Tab 內的 View，啟動 RecipeCoordinator 並注入 EnvironmentObject
private struct RecipeTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var recipeCoordinator: RecipeCoordinator?

    var body: some View {
        Group {
            if let recipeCoordinator = recipeCoordinator {
                // 用預設空的 SuggestRecipeResponse 先建立 ViewModel
                RecipeView(viewModel: RecipeViewModel(response: SuggestRecipeResponse(
                    dish_name: "",
                    dish_description: "",
                    ingredients: [],
                    equipment: [],
                    recipe: []
                )))
                .environmentObject(recipeCoordinator) // 注入 Coordinator
            } else {
                // 尚未建立 Coordinator 前，顯示載入指示器
                ProgressView()
                    .onAppear {
                        // 初始化 RecipeCoordinator 並加入父協調器管理
                        recipeCoordinator = RecipeCoordinator(navigationController: coordinator.navigationController)
                        coordinator.addChildCoordinator(recipeCoordinator!)
                    }
            }
        }
    }
}

/// Scanning Tab 內的 View，啟動 ScanningCoordinator 並注入 EnvironmentObject
private struct ScanningTabView: View {
    @ObservedObject var coordinator: MainTabCoordinator
    @State private var scanningCoordinator: ScanningCoordinator?

    var body: some View {
        Group {
            if let scanningCoordinator = scanningCoordinator {
                ScanningView(viewModel: ScanningViewModel())
                    .environmentObject(scanningCoordinator)
            } else {
                ProgressView()
                    .onAppear {
                        scanningCoordinator = ScanningCoordinator(navigationController: coordinator.navigationController)
                        coordinator.addChildCoordinator(scanningCoordinator!)
                    }
            }
        }
    }
}
