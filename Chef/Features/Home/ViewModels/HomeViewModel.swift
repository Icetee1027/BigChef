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
enum ViewState: Equatable {
    case loading
    case error(message: String)
    case dataLoaded
    
    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.dataLoaded, .dataLoaded):
            return true
        default:
            return false
        }
    }
}

// MARK: - Localized Strings
enum Strings {
    static let somethingWentWrong = "發生錯誤，請稍後再試"
    static let requestTimeout = "請求超時，請重試"
    static let fetchingRecords = "正在載入菜品資料..."
    static let fetchingMoreRecords = "正在載入更多資料..."
    static let noInternet = "網路連線異常，請檢查網路設定"
    static let noCharactersFound = "找不到相關菜品"
}

// MARK: - Home View Model
final class HomeViewModel: ObservableObject {
    // MARK: - Properties
    private let service: NetworkServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    @Published var viewState: ViewState = .loading
    @Published var allDishes: AllDishes?
    
    // MARK: - Coordinator Callbacks
    var onSelectDish: ((Dish) -> Void)?
    var onRequestLogout: (() -> Void)?
    
    // MARK: - Initialization
    init(service: NetworkServiceProtocol = NetworkService()) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func fetchAllDishes() {
        self.viewState = .loading
        
        service.request(url: "https://yummie.glitch.me/dish-categories", decodeType: APIResponse.self)
            .sink { [weak self] completion in
                guard let self = self else { return }
                switch completion {
                case .failure(let error):
                    print("HomeViewModel: 獲取菜品失敗 - \(error.localizedDescription)")
                    if let error = error as? URLError {
                        switch error.code {
                        case .timedOut:
                            self.viewState = .error(message: Strings.requestTimeout)
                        case .notConnectedToInternet:
                            self.viewState = .error(message: Strings.noInternet)
                        default:
                            self.viewState = .error(message: Strings.somethingWentWrong)
                        }
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

// MARK: - Preview Helper
extension HomeViewModel {
    static var preview: HomeViewModel {
        let viewModel = HomeViewModel()
        viewModel.allDishes = AllDishes.preview
        viewModel.viewState = .dataLoaded
        return viewModel
    }
}
