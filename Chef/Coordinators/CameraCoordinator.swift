//
//  CameraCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/3.
//

// Sources/Features/Camera/CameraCoordinator.swift
// Sources/Coordinators/Camera/CameraCoordinator.swift
import UIKit

final class CameraCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    private let nav: UINavigationController

    /// 當相機流程結束時，讓父協調器可以把它移除
    var onFinish: (() -> Void)?

    init(nav: UINavigationController) {
        self.nav = nav
    }

    
    func start() {
        let cookVC = CookViewController(steps: [])
        cookVC.title = "Camera"

        cookVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.close() }
        )

        nav.pushViewController(cookVC, animated: true)
    }
    /// Start cooking camera flow with recipe steps
    func start(with steps: [RecipeStep]) {
        let cameraVC = CookViewController(steps: steps)
        cameraVC.title = "Cooking Camera"

        cameraVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.close() }
        )

        nav.pushViewController(cameraVC, animated: true)
    }
    func startScanning() {
       let vc = ScanViewController()
       nav.pushViewController(vc, animated: true)
   }

   // 烹飪流程（帶步驟）
    func startCooking(with steps: [RecipeStep]) {
//       let vc = CookViewController(steps: steps)
//       nav.pushViewController(vc, animated: true)
//
        let vc = CookViewController(steps: steps)
        nav.pushViewController(vc, animated: false)
    }
    private func close() {
        nav.popViewController(animated: true)
        onFinish?()
    }
}
