//
//  HomeViewModel.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/8.
//

// HomeViewModel.swift
// 路徑: ntut-multimodal-ai-ar-cooking-app/bigchef/BigChef-main/Chef/Features/Home/ViewModels/HomeViewModel.swift
import Foundation
import Combine
import SwiftUI

// MARK: - View State
enum ViewState {
    case loading
    case error(message: String)
    case dataLoaded
}

// MARK: - Strings
enum Strings {
    static let somethingWentWrong = "Something went wrong!"
    static let requestTimeout = "Request timeout, please retry"
    static let fetchingRecords = "Fetching dishes, Please Be Patient"
    static let fetchingMoreRecords = "Fetching more records"
    static let noInternet = "Internet not available, please check internet connection"
    static let noCharactersFound = "No character found!"
}

final class HomeViewModel: ObservableObject {

    private let service: NetworkServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    @Published var viewState: ViewState = .loading
    @Published var allDishes: AllDishes?

    // MARK: - Coordinator Callbacks
    var onSelectDish: ((Dish) -> Void)? // 假設這個已存在或將來會用到
    var onRequestLogout: (() -> Void)?   // 新增：登出請求回調

    init(service: NetworkServiceProtocol = NetworkService()) {
        self.service = service
        // fetchAllDishes() // 考慮是否在 init 時自動載入，或由 View 的 onAppear 觸發
    }

    func fetchAllDishes() {
        self.viewState = .loading
        // 確保您的 API URL 正確
        service.request(url: "https://yummie.glitch.me/dish-categories", decodeType: APIResponse.self)
            .sink { [weak self] completion in
                guard let self = self else { return }
                switch completion {
                case .failure(let error):
                    print("HomeViewModel: 獲取菜品失敗 - \(error.localizedDescription)")
                    if let error = error as? URLError, error.code == .timedOut {
                        self.viewState = .error(message: Strings.requestTimeout)
                    } else {
                        self.viewState = .error(message: Strings.somethingWentWrong)
                    }
                case .finished:
                    print("HomeViewModel: 獲取菜品完成")
                }
            } receiveValue: { [weak self] responseData in
                guard let self = self else { return }
                self.allDishes = responseData.data
                self.viewState = .dataLoaded
            }
            .store(in: &cancellables)
    }

    // MARK: - User Actions
    func didSelectDish(_ dish: Dish) {
        onSelectDish?(dish)
    }

    func requestLogout() {
        print("HomeViewModel: 用戶請求登出")
        onRequestLogout?()
    }
}
