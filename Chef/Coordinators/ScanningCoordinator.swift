//
//  ScanningCoordinator.swift
//  ChefHelper
//

import UIKit
import SwiftUI      // 為了 UIHostingController

@MainActor
final class ScanningCoordinator: Coordinator, ObservableObject {

    // MARK: - Protocol Requirements
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    // MARK: - Private
    private unowned let nav: UINavigationController

    // MARK: - Init
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.nav = navigationController
    }

    // MARK: - Start
    func start() {
        let viewModel = ScanningViewModel()
        let view = ScanningView(viewModel: viewModel)
            .environmentObject(self)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }

    func showCamera() {
        let coordinator = CameraCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }
    
    func showRecipeDetail(_ recipe: SuggestRecipeResponse) {
        let coordinator = RecipeCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.showRecipeDetail(recipe)
    }
}
