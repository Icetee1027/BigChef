import SwiftUI

struct IngredientListView: View {
    @Binding var ingredients: [Ingredient]
    var onAdd: () -> Void
    var onEdit: (Ingredient) -> Void
    var onDelete: (Ingredient) -> Void

    var body: some View {
        CommonListView(
            title: "Ingredients",
            items: $ingredients,
            itemName: { $0.name },
            onAdd: onAdd,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }
}

struct IngredientEditView: View {
    @Binding var ingredient: Ingredient
    var onSave: () -> Void

    var body: some View {
        CommonEditView(
            title: ingredient.name.isEmpty ? "Add Ingredient" : "Edit Ingredient",
            item: $ingredient,
            fields: [
                ("Name", $ingredient.name, true),
                ("Type", $ingredient.type, false),
                ("Amount", $ingredient.amount, false),
                ("Unit", $ingredient.unit, false),
                ("Preparation", $ingredient.preparation, false)
            ],
            onSave: onSave
        )
    }
}
