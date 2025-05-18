//
//  APIResponse.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/8.
//


//
//  APIResponse.swift
//  Yummie
//
//  Created by Yogesh Patel on 06/06/23.
//

import Foundation

// MARK: - API Response Models
struct APIResponse: Decodable {
    let status: Int
    let message: String
    let data: AllDishes?
}

struct AllDishes: Decodable {
    let categories: [DishCategory]
    let populars: [Dish]
    let specials: [Dish]
}

// MARK: - Dish Category Model
struct DishCategory: Decodable, Identifiable {
    let id, name, image: String

    enum CodingKeys: String, CodingKey {
        case id
        case name = "title"
        case image
    }
}

// MARK: - Dish Model
struct Dish: Decodable, Identifiable {
    let id, name, description, image: String
    let calories: Int

    var formattedCalories: String {
        return "\(calories) calories"
    }
}

// MARK: - Preview Helpers
extension Dish {
    static let preview = Dish(
        id: "1",
        name: "測試菜品",
        description: "這是一個測試用的菜品描述",
        image: "https://picsum.photos/200",
        calories: 350
    )
}

extension DishCategory {
    static let preview = DishCategory(
        id: "1",
        name: "測試分類",
        image: "https://picsum.photos/200"
    )
}

extension AllDishes {
    static let preview = AllDishes(
        categories: [
            DishCategory.preview,
            DishCategory(id: "2", name: "測試分類2", image: "https://picsum.photos/201")
        ],
        populars: [
            Dish.preview,
            Dish(id: "2", name: "測試菜品2", description: "描述2", image: "https://picsum.photos/202", calories: 400)
        ],
        specials: [
            Dish.preview,
            Dish(id: "3", name: "測試菜品3", description: "描述3", image: "https://picsum.photos/203", calories: 450)
        ]
    )
}

extension APIResponse {
    static let preview = APIResponse(
        status: 200,
        message: "Success",
        data: AllDishes.preview
    )
}
