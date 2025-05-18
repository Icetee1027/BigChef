//
 //  HomeCoordinator.swift
 //  ChefHelper
 //
 //  Created by 陳泓齊 on 2025/5/3.
 //

import UIKit
import SwiftUI

@MainActor
final class HomeCoordinator: Coordinator {
    // MARK: - Properties
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: MainTabCoordinator?
    
    // MARK: - Initialization
    init(navigationController: UINavigationController, parentCoordinator: MainTabCoordinator? = nil) {
        self.navigationController = navigationController
        self.parentCoordinator = parentCoordinator
    }
    
    // MARK: - Public Methods
    func start() {
        let viewModel = HomeViewModel()
        viewModel.onSelectDish = { [weak self] dish in
            self?.showDishDetail(dish)
        }
        viewModel.onRequestLogout = { [weak self] in
            self?.handleLogout()
        }
        
        let homeView = HomeView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: homeView)
        navigationController.setViewControllers([hostingController], animated: false)
    }
    
    // MARK: - Navigation Methods
    func showDishDetail(_ dish: Dish) {
        // TODO: 實作顯示菜品詳情的導航
        print("顯示菜品詳情: \(dish.name)")
    }
    
    func handleLogout() {
        print("HomeCoordinator: 開始處理登出")
        
        // 清除用戶數據
        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.synchronize()
        
        // 通知父協調器處理登出
        if let parentCoordinator = parentCoordinator {
            print("HomeCoordinator: 通知父協調器處理登出")
            parentCoordinator.handleLogout()
        } else {
            print("HomeCoordinator: 錯誤 - 父協調器為空")
        }
    }
}

// MARK: - Preview Helper
extension HomeCoordinator {
    static var preview: HomeCoordinator {
        HomeCoordinator(navigationController: UINavigationController())
    }
}
