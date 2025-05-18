//
//  ScanViewController.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/7.
//

import UIKit

/// 掃描設備 / 食材畫面：
/// - 目前功能僅為顯示 AR 預覽畫面
/// - 後續計畫加入掃描框、Vision OCR、Lottie 動畫等輔助功能
@MainActor
final class ScanViewController: BaseCameraViewController<ARSessionAdapter> {
    
    /// 掃描畫面的 ViewModel，負責處理掃描邏輯與生成食譜的功能
    private let viewModel = ScanningViewModel()

    // MARK: - Init

    /// 初始化：使用繼承自 BaseCameraViewController 的構造器
    /// 傳入 ARSessionAdapter，代表此頁面使用 ARKit 相機
    init() {
        super.init(session: ARSessionAdapter())   // 共用 ARKit 相機的 adapter
    }

    /// Xcode 要求的必要初始化器（Storyboard 專用，此處不用）
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    /// 畫面載入完成時的處理邏輯
    override func viewDidLoad() {
        super.viewDidLoad()

        // 建立一個提示標籤，提示使用者將鏡頭對準器具或食材
        let label = UILabel()
        label.text = "將相機對準器具或食材…"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // 使用 Auto Layout 將提示標籤置於畫面底部中央
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])

        // 建立一個空的偏好設定，作為預設請求資料
        // 這邊先假設使用者沒有偏好，後續會由其他畫面填入實際值
        Task {
            let emptyPreference = Preference(
                cooking_method: "",
                dietary_restrictions: [],
                serving_size: "1人份"
            )
            // 呼叫 ViewModel 產生食譜（此處可能為模擬產生或初始化模型）
            await viewModel.generateRecipe(with: emptyPreference)
        }
    }
}
