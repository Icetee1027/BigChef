//
//  AppCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/3.
//

import UIKit

@MainActor
final class AppCoordinator: Coordinator {
    // MARK: - Properties
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    private let window: UIWindow
    
    // MARK: - Initialization
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    // MARK: - Coordinator
    func start() {
        let mainCoordinator = MainTabCoordinator(navigationController: navigationController)
        addChildCoordinator(mainCoordinator)
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        mainCoordinator.start()
    }
}
