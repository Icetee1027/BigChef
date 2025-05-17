//
//  ScanningCoordinator.swift
//  ChefHelper
//

import UIKit
import SwiftUI      // 為了 UIHostingController

final class ScanningCoordinator: Coordinator {

    // MARK: - Protocol Requirements
    var childCoordinators: [Coordinator] = []

    // MARK: - Private
    private unowned let nav: UINavigationController

    // MARK: - Init
    init(nav: UINavigationController) {
        self.nav = nav
    }

    // MARK: - Start
//    }
    func start() {
        let vm = ScanningViewModel()
        print("👀 Coordinator vm = \(Unmanaged.passUnretained(vm).toOpaque())")
        
        vm.onEquipmentScanRequested = { [weak self] in
            guard let self else { return }
            let camera = CameraCoordinator(nav: self.nav)
            self.childCoordinators.append(camera)
            camera.onFinish = { [weak self, weak camera] in
                guard let self, let camera else { return }
                self.childCoordinators.removeAll { $0 === camera }
            }
            camera.startScanning()
        }
        
        vm.onRecipeGenerated = { [weak self] resp in
            guard let self else { return }
            // 這裡一定要印得到
            print("🛫 ScanningCoordinator 收到 resp，準備 push")
            let recipe = RecipeCoordinator(nav: self.nav)
            self.childCoordinators.append(recipe)
            recipe.start(with: resp)
        }

        let page = ScanningView(viewModel: vm)
        nav.setNavigationBarHidden(true, animated: false)
        nav.pushViewController(UIHostingController(rootView: page), animated: false)
    }

}
