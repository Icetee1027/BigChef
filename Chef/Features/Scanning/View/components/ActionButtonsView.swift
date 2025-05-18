import SwiftUI

/// 這是一個用於顯示「掃描」與「產生食譜」按鈕的元件
struct ActionButtonsView: View {
    
    /// 按下「掃描」按鈕時要執行的動作（由外部注入）
    var onScan: () -> Void
    
    /// 按下「產生食譜」按鈕時要執行的動作（由外部注入）
    var onGenerate: () -> Void

    var body: some View {
        // 垂直堆疊兩個按鈕，按鈕間距為 12pt
        VStack(spacing: 12) {
            
            // 第一個按鈕：Scan
            Button(action: onScan) {
                HStack {
                    // 左側圖示：系統圖示「viewfinder」
                    Image(systemName: "viewfinder")
                        .resizable()              // 可調整尺寸
                        .scaledToFit()            // 縮放並保持比例
                        .frame(width: 30, height: 30)  // 設定圖示尺寸
                    
                    // 右側文字：「Scan」
                    Text("Scan")
                        .font(.headline)         // 使用標題字體
                        .foregroundColor(.brandOrange) // 自定義品牌橘色文字
                }
                .frame(maxWidth: .infinity)          // 水平方向撐滿可用空間
                .padding()                           // 內間距
                .background(Color.brandOrange.opacity(0.15)) // 背景為品牌橘色透明色塊
                .cornerRadius(12)                    // 邊角圓弧
            }

            // 第二個按鈕：Generate Recipe
            Button(action: onGenerate) {
                Text("Generate Recipe")
                    .font(.headline)                  // 使用標題字體
                    .foregroundColor(.white)          // 白色文字
                    .frame(maxWidth: .infinity)       // 水平方向撐滿
                    .padding()                        // 內間距
                    .background(Color.brandOrange)    // 背景為品牌橘色
                    .cornerRadius(12)                 // 邊角圓弧
            }
        }
    }
}
