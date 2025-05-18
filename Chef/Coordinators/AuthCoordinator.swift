//
//  AuthCoordinator.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/16.
//

import UIKit
import SwiftUI
import FirebaseAuth

@MainActor
final class AuthCoordinator: Coordinator, ObservableObject {
    // MARK: - Properties
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    private let authViewModel: AuthViewModel
    
    // MARK: - Initialization
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.authViewModel = AuthViewModel()
        setupViewModelCallbacks()
    }
    
    // MARK: - Coordinator
    func start() {
        if Auth.auth().currentUser != nil && authViewModel.currentUser != nil {
            // 用戶已登入，不需要顯示登入頁面
            return
        }
        
        if authViewModel.userSession != nil && authViewModel.currentUser == nil {
            // 嘗試重新獲取用戶資料
            authViewModel.fetchUser { [weak self] success in
                guard let self = self else { return }
                if !success || self.authViewModel.currentUser == nil {
                    self.showLoginView()
                }
            }
        } else {
            showLoginView()
        }
    }
    
    // MARK: - Private Methods
    private func setupViewModelCallbacks() {
        authViewModel.onLoginSuccess = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        
        authViewModel.onRegistrationSuccess = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        
        authViewModel.onNavigateToRegistration = { [weak self] in
            self?.showRegistrationView()
        }
        
        authViewModel.onNavigateBackToLogin = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        
        authViewModel.onAuthFailure = { [weak self] error in
            self?.showError(error)
        }
    }
    
    private func showLoginView() {
        let loginView = LoginView()
            .environmentObject(authViewModel)
        let hostingController = UIHostingController(rootView: loginView)
        hostingController.title = "登入"
        navigationController.setViewControllers([hostingController], animated: false)
    }
    
    private func showRegistrationView() {
        let registrationView = RegistrationView()
            .environmentObject(authViewModel)
        let hostingController = UIHostingController(rootView: registrationView)
        hostingController.title = "註冊帳號"
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "驗證錯誤",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        
        if let topVC = navigationController.topViewController,
           topVC.presentedViewController == nil {
            topVC.present(alert, animated: true)
        }
    }
}
