import UIKit
import Firebase

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    // MARK: - 屬性區

    /// UIWindow 是整個畫面的根容器
    var window: UIWindow?

    /// AppCoordinator 負責畫面流程的管理（登入/主畫面等）
    var appCoordinator: AppCoordinator?

    // MARK: - App 啟動時呼叫
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 初始化 Firebase（很重要，否則 Firebase 功能無法使用）
        FirebaseApp.configure()
        return true
    }

    // MARK: - 每當 app 建立新畫面（Scene）時會呼叫
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // 告訴系統這個畫面要使用哪個 Scene delegate class（這裡就是自己）
        let cfg = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        cfg.delegateClass = Self.self   // ← 關鍵
        return cfg
    }

    // MARK: - 每個畫面要顯示前都會呼叫這裡
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // 先確認這是個 UIWindowScene（iPad 或多視窗模式用）
        guard let windowScene = scene as? UIWindowScene else { return }

        // 初始化 UIWindow（畫面容器）
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // 建立 AppCoordinator 並交給它管理畫面
        let coordinator = AppCoordinator(window: window)
        self.appCoordinator = coordinator

        // 啟動 Coordinator（通常會顯示登入或主畫面）
        coordinator.start()

        print("✅ AppCoordinator.start() 完成，root = \(nav)")
    }
}
