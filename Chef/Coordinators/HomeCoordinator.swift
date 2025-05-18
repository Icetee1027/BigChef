//
//  HomeCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/3.
//

import UIKit

final class HomeCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private unowned let nav: UINavigationController
    init(nav: UINavigationController) { self.nav = nav }

    func start() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.title = "Home (stub)"
        nav.pushViewController(vc, animated: false)
    }
}
