import SwiftUI

/// 顯示圖片預覽畫面，包含描述提示欄位與掃描功能
struct ImagePreviewView: View {
    /// 要預覽的圖片（由外部傳入）
    let image: UIImage
    
    /// 使用者輸入的圖片描述提示（由外部綁定，便於資料共享）
    @Binding var descriptionHint: String
    
    /// 掃描圖片時要執行的動作，由外部注入
    let onScan: () -> Void
    
    /// 用於關閉當前畫面的 dismiss 控制器（來自環境變數）
    @Environment(\.dismiss) private var dismiss
    
    /// 是否正在掃描中，用來顯示 loading 狀態
    @State private var isScanning = false
    
    /// 是否顯示掃描完成的 alert
    @State private var showCompletionAlert = false
    
    /// 掃描完成後的摘要文字
    @State private var scanSummary = ""
    
    var body: some View {
        // 使用 NavigationStack 包覆整個畫面，支援上方導覽列
        NavigationStack {
            VStack(spacing: 20) {
                // 顯示圖片預覽
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                
                // 描述輸入區塊
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述提示（選填）")
                        .font(.headline)
                    
                    TextField("例如：蔬菜和鍋子", text: $descriptionHint)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 8)
                    
                    Text("描述圖片中的內容可以幫助系統更準確地識別食材和設備。")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer() // 推動按鈕到底部
                
                // 掃描按鈕
                Button(action: {
                    isScanning = true     // 進入掃描中狀態
                    onScan()              // 執行外部注入的掃描行為
                }) {
                    HStack {
                        if isScanning {
                            // 掃描中顯示轉圈圈
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(isScanning ? "掃描中..." : "開始掃描")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isScanning) // 掃描中不可再次點擊
            }
            .padding()
            .navigationTitle("圖片預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 導覽列左上角的取消按鈕
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss() // 關閉畫面
                    }
                    .disabled(isScanning) // 掃描中不可取消
                }
            }
            // 掃描完成後顯示彈窗提示
            .alert("掃描完成", isPresented: $showCompletionAlert) {
                Button("完成") {
                    dismiss() // 關閉畫面
                }
            } message: {
                Text(scanSummary) // 顯示掃描摘要內容
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 提供外部調用，用來設定掃描完成狀態與顯示 alert
    func setScanningComplete(summary: String) {
        isScanning = false
        scanSummary = summary
        showCompletionAlert = true
    }
}

// MARK: - Preview（用於預覽 SwiftUI 畫面）
#Preview {
    ImagePreviewView(
        image: UIImage(systemName: "photo")!, // 測試用預覽圖
        descriptionHint: .constant(""),       // 空的綁定提示文字
        onScan: {}                            // 空的掃描動作
    )
}
