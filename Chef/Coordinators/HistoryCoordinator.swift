//
//  HistoryCoordinator.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/8.
//


import UIKit
import SwiftUI

final class HistoryCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let nav: UINavigationController

    init(nav: UINavigationController) {
        self.nav = nav
    }

    func start() {
        let vm = HistoryViewModel()
        let view = HistoryView(viewModel: vm)
        let page = UIHostingController(rootView: view)
        nav.setNavigationBarHidden(true, animated: false)
        nav.pushViewController(page, animated: false)
    }
}
