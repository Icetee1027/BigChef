import SwiftUI

/// 使用者偏好輸入視圖，包括製作方式、飲食限制與份量選擇
struct PreferenceView: View {
    // 綁定外部狀態：烹飪方式（文字）
    @Binding var cookingMethod: String
    
    // 綁定外部狀態：飲食限制（文字）
    @Binding var dietaryRestrictionsInput: String
    
    // 綁定外部狀態：份量（整數）
    @Binding var servingSize: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題文字
            Text("Preference")
                .font(.title2)
                .bold()

            // 製作方式輸入區塊
            VStack(alignment: .leading, spacing: 4) {
                Text("製作方式（選填）")
                    .font(.headline)
                
                // 輸入框，綁定 cookingMethod 變數
                TextField("例如：煎、炒、煮...", text: $cookingMethod)
                    .textFieldStyle(.roundedBorder) // 使用圓角樣式
                    .autocorrectionDisabled(true)   // 關閉自動修正（避免鍵入被自動改掉）
            }

            // 飲食限制輸入區塊
            VStack(alignment: .leading, spacing: 4) {
                Text("飲食限制（選填）")
                    .font(.headline)
                
                // 輸入框，綁定 dietaryRestrictionsInput 變數
                TextField("例如：無麩質、素食...", text: $dietaryRestrictionsInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
            }

            // 份量選擇區塊
            HStack {
                Text("份量")
                    .font(.headline)
                Spacer()
                
                // 使用 Picker 提供 1~10 的選擇項目
                Picker("份量", selection: $servingSize) {
                    ForEach(1..<11) { size in
                        Text("\(size)人份").tag(size) // 每個選項加上 tag 對應綁定的數值
                    }
                }
                .pickerStyle(WheelPickerStyle()) // 滾輪樣式（像選時間那種）
                .frame(height: 60) // 限制 Picker 高度
            }
        }
    }
}
