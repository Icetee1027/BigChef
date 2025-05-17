//
//  Home.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/7.
//
// HomeView.swift

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    // @State var isNavigationToDish = false // 如果未使用，可以移除

    var body: some View {
        ZStack {
            switch viewModel.viewState {
            case .loading:
                ProgressView(Strings.fetchingRecords) // 確保 Strings.fetchingRecords 已定義
            case .error(let message):
                ErrorView(message) { // 確保 ErrorView 已定義
                    viewModel.fetchAllDishes()
                }
            case .dataLoaded:
                mainContent
            }
        }
        .onAppear {
            if viewModel.allDishes == nil {
                 viewModel.fetchAllDishes()
            }
        }
    }
    
    var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    Spacer()
                    Image("QuickFeatLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                    Spacer()
                    Button(action: {
                        viewModel.requestLogout()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Color.brandOrange)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // 使用 if let 來安全地解包 viewModel.allDishes
                if let unwrappedAllDishes = viewModel.allDishes {
                    // Food Category
                    // 直接使用 unwrappedAllDishes.categories，因為它不是可選的
                    // 並且檢查它是否為空
                    if !unwrappedAllDishes.categories.isEmpty { // <--- 修正點
                        VStack(alignment: .leading) {
                           SectionTitleView(title: "菜品分類")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 15) {
                                    // categories 現在是 unwrappedAllDishes.categories
                                    ForEach(unwrappedAllDishes.categories) { category in
                                        CategoryView(dish: category)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 128)
                        }
                        .padding(.bottom)
                    }

                    // Popular Dishes
                    // 同樣，直接使用 unwrappedAllDishes.populars
                    if !unwrappedAllDishes.populars.isEmpty {
                        VStack(alignment: .leading) {
                            SectionTitleView(title: "熱門菜品")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 15) {
                                    ForEach(unwrappedAllDishes.populars) { dish in
                                        PopularDishesView(dish: dish)
                                            .onTapGesture {
                                                viewModel.didSelectDish(dish)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 250)
                        }
                        .padding(.bottom)
                    }

                    // Recommended Dishes
                    // 同樣，直接使用 unwrappedAllDishes.specials
                    if !unwrappedAllDishes.specials.isEmpty {
                        VStack(alignment: .leading) {
                            SectionTitleView(title: "推薦菜品")
                            LazyVStack(spacing: 15) {
                                ForEach(unwrappedAllDishes.specials) { dish in
                                    RecommendedView(dish: dish)
                                        .onTapGesture {
                                            viewModel.didSelectDish(dish)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // 當 viewModel.allDishes 為 nil 時 (例如還在載入中或載入失敗且 viewState 不是 .dataLoaded)
                    // 這裡可以選擇顯示一個提示，或者依賴 ZStack 中的 ProgressView/ErrorView
                    Text("正在載入菜品資料...") // 或者保持為空，讓外層 ZStack 處理
                        .padding()
                }
                Spacer(minLength: 80)
            }
        }
        .background(Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all))
    }
}

