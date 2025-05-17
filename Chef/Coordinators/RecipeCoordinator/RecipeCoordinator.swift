////
////  RecipeCoordinator.swift
////  ChefHelper
////
////  Created by 陳泓齊 on 2025/5/4.
////
//
//import SwiftUI
//
//final class RecipeCoordinator: Coordinator {
//    var childCoordinators: [Coordinator] = []
//    private unowned let nav: UINavigationController
//    func start() {fatalError("Use start(with:) instead.") }
//    //MARK: - Init
//    init(nav: UINavigationController) {
//        self.nav = nav
//    }
//    //MARK: - Start
//    func start(with response: SuggestRecipeResponse) {
//        print("📦 RecipeCoordinator - start \(response.dish_name)")
//        let vm = RecipeViewModel(response: response)
//        print("📦 RecipeCoordinator - pushing RecipeView1")
//        // ① 設定 callback
//        vm.onCookRequested = { [weak self] in
//            guard let self else { return }
//            let camera = CameraCoordinator(nav: self.nav)
//            self.childCoordinators.append(camera)
//            camera.onFinish = { [weak self, weak camera] in
//                guard let self, let camera else { return }
//                self.childCoordinators.removeAll { $0 === camera }
//            }
//            camera.start(with: response.recipe) // push camera with all steps
//        }
//        print("📦 RecipeCoordinator - pushing RecipeView")
//        let page = UIHostingController(rootView: RecipeView(viewModel: vm))
//        nav.pushViewController(page, animated: true)
//    }
//
//}

import SwiftUI

@MainActor
final class RecipeCoordinator: Coordinator, ObservableObject {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        // 創建一個空的食譜列表視圖
        let viewModel = RecipeViewModel(response: SuggestRecipeResponse(
            dish_name: "",
            dish_description: "",
            ingredients: [],
            equipment: [],
            recipe: []
        ))
        pushRecipeView(with: viewModel)
    }
    
    func showRecipeDetail(_ recipe: SuggestRecipeResponse) {
        let viewModel = RecipeViewModel(response: recipe)
        viewModel.onCookRequested = { [weak self] in
            self?.startCooking(with: recipe.recipe)
        }
        pushRecipeView(with: viewModel)
    }
    
    func showRecipeEdit(_ recipe: SuggestRecipeResponse) {
        pushRecipeView(with: RecipeViewModel(response: recipe))
    }
    
    func showScanning() {
        let coordinator = ScanningCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }
    
    func showCamera() {
        let coordinator = CameraCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }
    
    // MARK: - Private Helpers
    
    private func pushRecipeView(with viewModel: RecipeViewModel) {
        let view = RecipeView(viewModel: viewModel)
            .environmentObject(self)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    private func startCooking(with steps: [RecipeStep]) {
        let coordinator = CookCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start(with: steps)
    }
}
