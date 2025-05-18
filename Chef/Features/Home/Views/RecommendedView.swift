//
//  RecommendedView.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/12.
//

import SwiftUI

struct RecommendedView: View {
    // MARK: - Properties
    let dish: Dish
    let onTap: (() -> Void)?
    
    // MARK: - Initialization
    init(dish: Dish, onTap: (() -> Void)? = nil) {
        self.dish = dish
        self.onTap = onTap
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // 圖片
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
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 內容
                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(dish.description)
                        .font(.subheadline)
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
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 收藏按鈕
                Image(systemName: "heart")
                    .foregroundColor(.pink)
                    .font(.title3)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct RecommendedView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 15) {
                RecommendedView(dish: Dish.preview)
                RecommendedView(
                    dish: Dish(
                        id: "2",
                        name: "測試菜品2",
                        description: "這是一個較長的描述文字，用來測試多行文字的顯示效果。這是一個較長的描述文字，用來測試多行文字的顯示效果。",
                        image: "https://picsum.photos/202",
                        calories: 400
                    ),
                    onTap: { print("菜品被點擊") }
                )
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .previewLayout(.sizeThatFits)
    }
}
