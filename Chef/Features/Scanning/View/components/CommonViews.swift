import SwiftUI

// MARK: - 通用列表畫面（顯示可編輯項目列表的元件）
struct CommonListView<T: Identifiable & Equatable>: View {
    let title: String                         // 標題文字
    @Binding var items: [T]                  // 資料來源，為綁定陣列，外部傳入
    let itemName: (T) -> String              // 回傳項目顯示名稱的函式
    var onAdd: () -> Void                    // 點擊新增按鈕的處理函式
    var onEdit: (T) -> Void                  // 點擊編輯按鈕的處理函式
    var onDelete: (T) -> Void                // 點擊刪除按鈕的處理函式
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus.circle")
                        .labelStyle(IconOnlyLabelStyle()) // 只顯示 icon
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            
            LazyVStack {
                ForEach(items) { item in
                    HStack {
                        Text(itemName(item)) // 顯示項目名稱
                        Spacer()
                        Button("Edit") {
                            onEdit(item)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 通用編輯畫面（支援多欄位輸入與驗證）
struct CommonEditView<T: Identifiable & Equatable>: View {
    let title: String                                    // 編輯畫面標題
    @Binding var item: T                                 // 欲編輯的項目（雙向綁定）
    var fields: [(String, Binding<String>, Bool)]        // 欄位資料：名稱、綁定值、是否必填
    var onSave: () -> Void                               // 儲存時呼叫的動作
    @Environment(\.dismiss) private var dismiss          // 系統 dismiss 操作（關閉畫面）
    @State private var errors: [String: String] = [:]    // 驗證錯誤訊息

    // 檢查是否有任何錯誤存在
    private var hasErrors: Bool {
        !errors.isEmpty
    }

    // 檢查所有必填欄位是否都填寫正確（非空白）
    private var requiredFieldsAreValid: Bool {
        fields.allSatisfy { field in
            let (_, binding, isRequired) = field
            if !isRequired { return true }
            return !binding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // 是否允許按下「儲存」
    private var canSave: Bool {
        !hasErrors && requiredFieldsAreValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 為每個欄位建立輸入框與錯誤提示
                    ForEach(fields, id: \.0) { field in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(field.0 + (field.2 ? " *" : ""), text: field.1)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: field.1.wrappedValue) { oldValue, newValue in
                                    validateField(field.0, binding: field.1, isRequired: field.2)
                                }
                            if let error = errors[field.0] {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    // 若有任何欄位為必填，顯示提示文字
                    if fields.contains(where: { $0.2 }) {
                        Text("Fields marked with * are required")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// 驗證單一欄位（若是必填且為空白，加入錯誤）
    private func validateField(_ name: String, binding: Binding<String>, isRequired: Bool) {
        if isRequired && binding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
            errors[name] = "\(name) is required"
        } else {
            errors.removeValue(forKey: name)
        }
    }
}

// MARK: - 自訂 View 修飾器（View Modifier）
extension View {
    /// 加上圓角樣式的輸入框（語法糖）
    func roundedTextField() -> some View {
        self.textFieldStyle(.roundedBorder)
    }

    /// 為清單每行加上預設樣式（上下內距）
    func listRowStyle() -> some View {
        self.padding(.vertical, 4)
    }
}
