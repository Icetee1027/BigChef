import SwiftUI


// MARK: - Sheet Type
enum ScanningSheet: Identifiable {
    case ingredient(Ingredient)
    case equipment(Equipment)
    
    var id: String {
        switch self {
        case .ingredient(let item): return "ingredient-\(item.id)"
        case .equipment(let item): return "equipment-\(item.id)"
        }
    }
}

// MARK: - Main View
struct ScanningView: View {
    @StateObject private var viewModel: ScanningViewModel
    @State private var state: ScanningState
    @EnvironmentObject private var coordinator: ScanningCoordinator
    
    init(
        viewModel: ScanningViewModel,
        initialState: ScanningState = ScanningState()
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._state = State(initialValue: initialState)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    logoView
                    equipmentSection
                    ingredientSection
                    preferenceSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Recipe Generator")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $state.activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(isPresented: $viewModel.isShowingImagePreview) {
                if let image = viewModel.selectedImage {
                    ImagePreviewView(
                        image: image,
                        descriptionHint: $viewModel.descriptionHint,
                        onScan: {
                            Task {
                                let request = ScanImageRequest(
                                    image: ImageCompressor.compressToBase64(image: image) ?? "",
                                    description_hint: viewModel.descriptionHint
                                )
                                await viewModel.scanImage(request: request)
                            }
                        }
                    )
                    .onAppear {
                        setupScanCompletionHandler()
                    }
                }
            }
            .alert("掃描完成", isPresented: $state.showCompletionAlert) {
                Button("完成", role: .cancel) {
                    cleanupAfterScan()
                }
            } message: {
                Text(state.scanSummary)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .imageSourcePicker(
                isPresented: $viewModel.isShowingImagePicker,
                selectedImage: $viewModel.selectedImage,
                onImageSelected: { image in
                    viewModel.selectedImage = image
                    viewModel.isShowingImagePreview = true
                }
            )
            .onAppear {
                setupRecipeNavigationHandler()
            }
        }
    }
    
    // MARK: - View Components
    
    private var logoView: some View {
        HStack {
            Spacer()
            Image("QuickFeatLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
        }
    }
    
    private var equipmentSection: some View {
        EquipmentListView(
            equipment: $viewModel.equipment,
            onAdd: { state.activeSheet = .equipment(Equipment.empty) },
            onEdit: { equipment in state.activeSheet = .equipment(equipment) },
            onDelete: { equipment in
                withAnimation(.easeInOut) {
                    viewModel.removeEquipment(equipment)
                }
            }
        )
    }
    
    private var ingredientSection: some View {
        IngredientListView(
            ingredients: $viewModel.ingredients,
            onAdd: { state.activeSheet = .ingredient(Ingredient.empty) },
            onEdit: { ingredient in state.activeSheet = .ingredient(ingredient) },
            onDelete: { ingredient in
                withAnimation(.easeInOut) {
                    viewModel.removeIngredient(ingredient)
                }
            }
        )
    }
    
    private var preferenceSection: some View {
        PreferenceView(
            cookingMethod: Binding(
                get: { state.preference.cooking_method },
                set: { state.preference.cooking_method = $0 }
            ),
            dietaryRestrictionsInput: Binding(
                get: { state.preference.dietary_restrictions.joined(separator: ", ") },
                set: { state.preference.dietary_restrictions = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ),
            servingSize: Binding(
                get: { Int(state.preference.serving_size.replacingOccurrences(of: "人份", with: "")) ?? 1 },
                set: { state.preference.serving_size = "\($0)人份" }
            )
        )
    }
    
    private var actionButtons: some View {
        ActionButtonsView(
            onScan: {
                viewModel.isShowingImagePicker = true
            },
            onGenerate: {
                Task {
                    await viewModel.generateRecipe(with: state.preference)
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func setupScanCompletionHandler() {
        viewModel.onScanCompleted = { response, summary in
            Task { @MainActor in
                // 更新食材列表
                for ingredient in response.ingredients {
                    withAnimation(.easeInOut) {
                        viewModel.upsertIngredient(ingredient)
                    }
                }
                
                // 更新設備列表
                for equipment in response.equipment {
                    withAnimation(.easeInOut) {
                        viewModel.upsertEquipment(equipment)
                    }
                }
                
                // 更新 UI 狀態
                withAnimation {
                    viewModel.isShowingImagePreview = false
                    state.scanSummary = summary
                    state.showCompletionAlert = true
                }
            }
        }
    }
    
    private func setupRecipeNavigationHandler() {
        viewModel.onNavigateToRecipe = { [weak coordinator] recipe in
            coordinator?.showRecipeDetail(recipe)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: ScanningSheet) -> some View {
        switch sheet {
        case .ingredient(let ingredient):
            let binding = binding(for: ingredient, in: $viewModel.ingredients)
            IngredientEditView(
                ingredient: binding,
                onSave: {
                    withAnimation(.easeInOut) {
                        viewModel.upsertIngredient(binding.wrappedValue)
                        state.activeSheet = nil
                    }
                }
            )
        case .equipment(let equipment):
            let binding = binding(for: equipment, in: $viewModel.equipment)
            EquipmentEditView(
                equipment: binding,
                onSave: {
                    withAnimation(.easeInOut) {
                        viewModel.upsertEquipment(binding.wrappedValue)
                        state.activeSheet = nil
                    }
                }
            )
        }
    }
    
    private func binding<T: Identifiable & Equatable>(
        for item: T,
        in array: Binding<[T]>
    ) -> Binding<T> {
        Binding(
            get: {
                array.wrappedValue.first(where: { $0.id == item.id }) ?? item
            },
            set: { newValue in
                if let index = array.wrappedValue.firstIndex(where: { $0.id == item.id }) {
                    array.wrappedValue[index] = newValue
                } else {
                    array.wrappedValue.append(newValue)
                }
            }
        )
    }
    
    private func cleanupAfterScan() {
        Task { @MainActor in
            viewModel.selectedImage = nil
            viewModel.descriptionHint = ""
            state.showCompletionAlert = false
            state.scanSummary = ""
        }
    }
}



// MARK: - Preview
struct ScanningView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let viewModel = ScanningViewModel()
        viewModel.ingredients = [
            Ingredient(
                name: "蛋",
                type: "蛋類",
                amount: "2",
                unit: "顆",
                preparation: "打散"
            )
        ]
        viewModel.equipment = [
            Equipment(
                name: "平底鍋",
                type: "鍋具",
                size: "小型",
                material: "不沾",
                power_source: "電"
            )
        ]
        
        return ScanningView(
            viewModel: viewModel,
            initialState: ScanningState(
                preference: Preference(
                    cooking_method: "煎",
                    dietary_restrictions: ["無麩質"],
                    serving_size: "1人份"
                )
            )
        )
        .preferredColorScheme(.light)
    }
}
