//
//  Coordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/3.
//

protocol Coordinator: AnyObject {
    /// 子 Coordinator 陣列，用於管理多個子流程或頁面
    var childCoordinators: [Coordinator] { get set }
    
    /// 導航控制器，用來管理畫面堆疊與導航
    var navigationController: UINavigationController { get set }
    
    /// 啟動 Coordinator 的入口，通常用來設定初始畫面
    func start()
}

extension Coordinator {
    /// 新增子 Coordinator，方便管理多個子流程
    func addChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }
    
    /// 移除子 Coordinator，結束其流程與釋放資源
    func removeChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
