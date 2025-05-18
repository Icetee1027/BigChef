//
//  PopularDishesView.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/12.
//

import SwiftUI

struct PopularDishesView: View {
    // MARK: - Properties
    let dish: Dish
    let onTap: (() -> Void)?
    let isFavorite: Bool
    let onFavoriteTapped: (() -> Void)?
    
    // MARK: - Initialization
    init(
        dish: Dish,
        isFavorite: Bool = false,
        onTap: (() -> Void)? = nil,
        onFavoriteTapped: (() -> Void)? = nil
    ) {
        self.dish = dish
        self.isFavorite = isFavorite
        self.onTap = onTap
        self.onFavoriteTapped = onFavoriteTapped
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                // 收藏按鈕和圖片
                HStack(alignment: .top) {
                    Button(action: { onFavoriteTapped?() }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(isFavorite ? .pink : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    CachedAsyncImage(
                        url: URL(string: dish.image),
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                        }
                    )
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
                
                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(dish.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        // 熱量
                        Label(dish.formattedCalories, systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.pink)
                        
                        Spacer()
                        
                        // 評分
                        HStack(spacing: 2) {
                            ForEach(0..<5) { _ in
                                Image(systemName: "star.fill")
                                    .renderingMode(.template)
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(width: 180)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct PopularDishesView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                PopularDishesView(dish: Dish.preview)
                PopularDishesView(
                    dish: Dish(
                        id: "2",
                        name: "測試菜品2",
                        description: "這是一個較長的描述文字，用來測試多行文字的顯示效果。",
                        image: "https://picsum.photos/202",
                        calories: 400
                    ),
                    isFavorite: true,
                    onTap: { print("菜品被點擊") },
                    onFavoriteTapped: { print("收藏按鈕被點擊") }
                )
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .previewLayout(.sizeThatFits)
    }
}
