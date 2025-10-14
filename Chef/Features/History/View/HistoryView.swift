//
//  HistoryView.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/8.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @State private var showingSortOptions = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecipeForDelete: String?
    @State private var selectedRecipeDetail: RecipeHistory?

    var body: some View {
        VStack(spacing: 0) {
            // 頂部標題列（固定）
            HStack {
                Text("歷史記錄")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    ForEach(HistorySortOrder.allCases, id: \.self) { order in
                        Button {
                            viewModel.selectedSortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if viewModel.selectedSortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.title3)
                }
                
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // 歷史記錄類型選擇器（固定）
            historyTypePicker
            
            // 內容列表（包含所有可滾動內容）
            if viewModel.isLoading {
                loadingView
            } else if !hasContent {
                emptyView
            } else {
                contentList
            }
        }
        .alert("確認刪除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                if let id = selectedRecipeForDelete {
                    viewModel.deleteRecord(id: id)
                    selectedRecipeForDelete = nil
                }
            }
        } message: {
            Text("確定要刪除這筆記錄嗎？此操作無法復原。")
        }
        .sheet(item: $selectedRecipeDetail) { history in
            RecipeHistoryDetailView(history: history)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasContent: Bool {
        switch viewModel.selectedHistoryType {
        case .recipes:
            return !viewModel.filteredRecipes.isEmpty
        case .foodRecognition:
            return !viewModel.foodRecognitionHistories.isEmpty
        case .ingredientRecognition:
            return !viewModel.ingredientRecognitionHistories.isEmpty
        }
    }
    
    // MARK: - Subviews
    
    private var historyTypePicker: some View {
        Picker("歷史類型", selection: $viewModel.selectedHistoryType) {
            ForEach(HistoryType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.icon)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var statisticsBar: some View {
        HStack {
            if viewModel.selectedHistoryType == .recipes {
                StatisticItem(
                    icon: "doc.text.fill",
                    value: "\(viewModel.statistics.total)",
                    label: "總食譜"
                )
                
                Divider()
                    .frame(height: 30)
                
                StatisticItem(
                    icon: "star.fill",
                    value: "\(viewModel.statistics.favorites)",
                    label: "收藏"
                )
            } else {
                StatisticItem(
                    icon: "doc.text.fill",
                    value: "\(viewModel.statistics.total)",
                    label: "總記錄"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var contentList: some View {
        Group {
            switch viewModel.selectedHistoryType {
            case .recipes:
                recipeList
            case .foodRecognition:
                foodRecognitionList
            case .ingredientRecognition:
                ingredientRecognitionList
            }
        }
    }
    
    private var recipeList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 搜尋列
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                // 篩選器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: viewModel.selectedFilter == filter
                            ) {
                                viewModel.selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                
                // 統計資訊
                statisticsBar
                    .padding(.bottom, 8)
                
                // 卡片列表
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredRecipes) { history in
                        RecipeHistoryCard(
                            history: history,
                            onTap: {
                                selectedRecipeDetail = history
                            },
                            onFavoriteToggle: {
                                viewModel.toggleFavorite(id: history.id)
                            },
                            onDelete: {
                                selectedRecipeForDelete = history.id
                                showingDeleteAlert = true
                            },
                            onReuse: {
                                viewModel.incrementUsage(id: history.id)
                                viewModel.onReuseRecipe?(history)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var foodRecognitionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 統計資訊
                statisticsBar
                    .padding(.bottom, 8)
                
                // 卡片列表
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.foodRecognitionHistories) { history in
                        FoodRecognitionHistoryCard(
                            history: history,
                            onReuse: {
                                viewModel.onReuseFoodRecognition?(history)
                            },
                            onDelete: {
                                selectedRecipeForDelete = history.id
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var ingredientRecognitionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 統計資訊
                statisticsBar
                    .padding(.bottom, 8)
                
                // 卡片列表
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.ingredientRecognitionHistories) { history in
                        IngredientRecognitionHistoryCard(
                            history: history,
                            onReuse: {
                                viewModel.onReuseIngredientRecognition?(history)
                            },
                            onDelete: {
                                selectedRecipeForDelete = history.id
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("尚無歷史記錄")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("開始製作食譜後，您的歷史記錄將會顯示在這裡")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brandOrange : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct StatisticItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.brandOrange)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecipeHistoryCard: View {
    let history: RecipeHistory
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    let onDelete: () -> Void
    let onReuse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 主內容區域（可點擊查看詳情）
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    // 標題列
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(history.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(history.response.dish_description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    
                    // 資訊列
                    HStack(spacing: 16) {
                        Label("\(history.response.recipe.count) 步驟", systemImage: "list.number")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("使用 \(history.usageCount) 次", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 時間
                    Text(formatTimestamp(history.lastUsedAt ?? history.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // 操作按鈕列
            HStack(spacing: 16) {
                // 收藏按鈕
                Button(action: onFavoriteToggle) {
                    HStack(spacing: 4) {
                        Image(systemName: history.isFavorite ? "star.fill" : "star")
                        Text(history.isFavorite ? "已收藏" : "收藏")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(history.isFavorite ? .yellow : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 再次使用按鈕
                Button(action: onReuse) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("再次使用")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandOrange)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 刪除按鈕
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                        .padding(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛使用"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分鐘前使用"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小時前使用"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前使用"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Food Recognition History Card

struct FoodRecognitionHistoryCard: View {
    let history: FoodRecognitionHistory
    let onReuse: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題列
            HStack(alignment: .top) {
                Image(systemName: "camera.fill")
                    .foregroundColor(.brandOrange)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.displayName)
                        .font(.headline)
                    
                    if let summary = history.response.primaryFood?.description {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // 資訊列
            HStack(spacing: 16) {
                Label("\(history.response.recognizedFoods.count) 種食物", systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("使用 \(history.usageCount) 次", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 時間
            Text(formatTimestamp(history.lastUsedAt ?? history.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            // 操作按鈕列
            HStack(spacing: 16) {
                // 再次使用按鈕
                Button(action: onReuse) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("再次使用")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandOrange)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 刪除按鈕
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("刪除")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛使用"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分鐘前使用"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小時前使用"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前使用"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Ingredient Recognition History Card

struct IngredientRecognitionHistoryCard: View {
    let history: IngredientRecognitionHistory
    let onReuse: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題列
            HStack(alignment: .top) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.displayName)
                        .font(.headline)
                    
                    Text(history.response.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // 資訊列
            HStack(spacing: 16) {
                Label("\(history.response.ingredients.count) 食材", systemImage: "carrot")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("\(history.response.equipment.count) 器具", systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("使用 \(history.usageCount) 次", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 時間
            Text(formatTimestamp(history.lastUsedAt ?? history.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            // 操作按鈕列
            HStack(spacing: 16) {
                // 再次使用按鈕
                Button(action: onReuse) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("再次使用")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandOrange)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 刪除按鈕
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("刪除")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛使用"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分鐘前使用"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小時前使用"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前使用"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Recipe History Detail View

struct RecipeHistoryDetailView: View {
    let history: RecipeHistory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 菜名與描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text(history.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(history.response.dish_description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 食材列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "carrot.fill")
                                .foregroundColor(.brandOrange)
                            Text("食材 (\(history.response.ingredients.count))")
                                .font(.headline)
                        }
                        
                        ForEach(history.response.ingredients) { ingredient in
                            HStack {
                                Text("•")
                                Text("\(ingredient.name) - \(ingredient.amount)\(ingredient.unit)")
                                Spacer()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 器具列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "frying.pan.fill")
                                .foregroundColor(.brandOrange)
                            Text("器具 (\(history.response.equipment.count))")
                                .font(.headline)
                        }
                        
                        ForEach(history.response.equipment) { equipment in
                            HStack {
                                Text("•")
                                Text(equipment.name)
                                Spacer()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 烹飪步驟
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.brandOrange)
                            Text("烹飪步驟 (\(history.response.recipe.count))")
                                .font(.headline)
                        }
                        
                        ForEach(history.response.recipe) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(step.step_number). \(step.title)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(step.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Label(step.estimated_total_time, systemImage: "clock")
                                    Text("·")
                                    Label(step.temperature, systemImage: "flame")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("食譜詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel())
}
