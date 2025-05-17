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
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.title = "Home (stub)"
        navigationController.pushViewController(vc, animated: false)
    }
}
