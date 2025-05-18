import SwiftUI

/// 設定頁面，讓使用者可以設定個人資訊、通知偏好與查看版本資訊
struct SettingsView: View {
    // 使用 @AppStorage 綁定 UserDefaults 中的設定，方便自動存取與更新
    
    /// 使用者名稱
    @AppStorage("userName") private var userName: String = ""
    
    /// 烹飪等級，預設為「初學者」
    @AppStorage("cookingLevel") private var cookingLevel: String = "初學者"
    
    /// 通知是否啟用，預設為 true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    
    /// 烹飪等級選項清單
    private let cookingLevels = ["初學者", "中級", "進階", "專業"]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 個人設定區塊
                Section(header: Text("個人設定")) {
                    // 輸入使用者名稱
                    TextField("使用者名稱", text: $userName)
                    
                    // 烹飪等級選擇器
                    Picker("烹飪等級", selection: $cookingLevel) {
                        ForEach(cookingLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                }
                
                // MARK: - 通知設定區塊
                Section(header: Text("通知設定")) {
                    // 開關控制是否啟用通知
                    Toggle("啟用通知", isOn: $notificationsEnabled)
                }
                
                // MARK: - 關於區塊
                Section(header: Text("關於")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        // 從 Info.plist 讀取 App 版本號，若讀不到則預設顯示 1.0.0
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

// 預覽
#Preview {
    SettingsView()
}
