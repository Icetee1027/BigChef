import UIKit

/// AppCoordinator 負責 App 啟動後的流程控制（例如：登入 -> 主頁）
/// 採用 Coordinator Pattern 以便模組化各個流程
@MainActor
final class AppCoordinator: Coordinator {
    
    // MARK: - Properties
    
    /// 管理子流程協調器（例如：登入流程、主畫面流程）
    var childCoordinators: [Coordinator] = []
    
    /// 主導航控制器，用來顯示所有畫面（navigation-based flow）
    var navigationController: UINavigationController
    
    /// UIWindow 是 App 的畫面容器，透過它設定初始畫面
    private let window: UIWindow
    
    // MARK: - Initialization
    
    /// 建構時注入 UIWindow，並建立主導航控制器
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    // MARK: - Coordinator
    
    /// 開始 App 流程，決定第一個畫面要顯示什麼（這裡是 MainTabCoordinator）
    func start() {
        // 建立主頁流程的協調器（例如登入後看到的主畫面）
        let mainCoordinator = MainTabCoordinator(navigationController: navigationController)
        
        // 將它加入管理清單中，避免記憶體被釋放
        addChildCoordinator(mainCoordinator)
        
        // 設定根畫面為 navigationController（包含 MainTab 畫面）
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        // 啟動主頁流程
        mainCoordinator.start()
    }
}
