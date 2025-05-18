import SwiftUI

struct EquipmentListView: View {
    @Binding var equipment: [Equipment]
    var onAdd: () -> Void
    var onEdit: (Equipment) -> Void
    var onDelete: (Equipment) -> Void

    var body: some View {
        CommonListView(
            title: "Equipment",
            items: $equipment,
            itemName: { $0.name },
            onAdd: onAdd,
            onEdit: onEdit,
            onDelete: onDelete
        )
                }
            }

struct EquipmentEditView: View {
    @Binding var equipment: Equipment
    var onSave: () -> Void

    var body: some View {
        CommonEditView(
            title: equipment.name.isEmpty ? "Add Equipment" : "Edit Equipment",
            item: $equipment,
            fields: [
                ("Name", $equipment.name, true),
                ("Type", $equipment.type, false),
                ("Size", $equipment.size, false),
                ("Material", $equipment.material, false),
                ("Power Source", $equipment.power_source, false)
            ],
            onSave: onSave
        )
    }
}
