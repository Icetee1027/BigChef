//
//  FoodRecognitionViewModel.swift
//  ChefHelper
//
//  Created by Claude on 2025/9/18.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FoodRecognitionViewModel: ObservableObject {

    // MARK: - Dependencies
    private let foodRecognitionService: FoodRecognitionServiceProtocol
    private let state: FoodRecognitionState

    // MARK: - Published Properties (從 State 導出)
    @Published var recognitionStatus: RecognitionStatus = .idle
    @Published var selectedImage: UIImage?
    @Published var recognitionResult: FoodRecognitionResponse?
    @Published var error: FoodRecognitionError?
    @Published var showImagePicker = false
    @Published var showCamera = false
    @Published var descriptionHint = ""

    // MARK: - 新增的 UI 控制屬性
    @Published var showImageSourcePicker = false
    @Published var retryCount = 0
    @Published var isRetrying = false
    @Published var uploadProgress: Double = 0.0

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryCount = 3

    // MARK: - Computed Properties

    var isLoading: Bool {
        recognitionStatus == .loading || isRetrying
    }

    var hasError: Bool {
        error != nil
    }

    var hasResult: Bool {
        recognitionResult?.hasResults == true
    }

    var hasSelectedImage: Bool {
        selectedImage != nil
    }

    var statusDescription: String {
        switch recognitionStatus {
        case .idle:
            return hasSelectedImage ? "點擊辨識按鈕開始辨識" : "請選擇要辨識的食物圖片"
        case .loading:
            if isRetrying {
                return "正在重試辨識... (\(retryCount)/\(maxRetryCount))"
            }
            return "正在辨識中..."
        case .success:
            return recognitionResult?.summary ?? "辨識完成"
        case .error:
            return error?.localizedDescription ?? "辨識失敗"
        }
    }

    /// 取得主要辨識結果
    var primaryResult: RecognizedFood? {
        recognitionResult?.primaryFood
    }

    /// 檢查錯誤是否可重試
    var isErrorRetryable: Bool {
        guard let error = error else { return false }
        return error.category.isRetryable && retryCount < maxRetryCount
    }

    /// 檢查是否可以開始辨識
    var canStartRecognition: Bool {
        hasSelectedImage && !isLoading
    }

    /// 取得當前狀態的進度值（用於進度條）
    var recognitionProgress: Double {
        switch recognitionStatus {
        case .idle:
            return hasSelectedImage ? 0.2 : 0.0
        case .loading:
            return min(0.9, 0.3 + uploadProgress * 0.6)
        case .success:
            return 1.0
        case .error:
            return 0.0
        }
    }

    // MARK: - Initialization

    init(
        foodRecognitionService: FoodRecognitionServiceProtocol = FoodRecognitionService.shared,
        state: FoodRecognitionState? = nil
    ) {
        self.foodRecognitionService = foodRecognitionService
        self.state = state ?? FoodRecognitionState()
        setupBindings()
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // 監聽從歷史記錄顯示食物辨識結果
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowFoodRecognitionHistory"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let response = userInfo["response"] as? FoodRecognitionResponse else {
                return
            }
            
            Task { @MainActor in
                // 設置辨識結果
                self.state.setSuccess(with: response)
                print("✅ 從歷史記錄載入食物辨識結果")
            }
        }
    }

    // MARK: - Private Setup

    private func setupBindings() {
        // 綁定 state 的變化到 published 屬性
        state.$recognitionStatus
            .assign(to: \.recognitionStatus, on: self)
            .store(in: &cancellables)

        state.$selectedImage
            .assign(to: \.selectedImage, on: self)
            .store(in: &cancellables)

        state.$recognitionResult
            .assign(to: \.recognitionResult, on: self)
            .store(in: &cancellables)

        state.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)

        state.$showImagePicker
            .assign(to: \.showImagePicker, on: self)
            .store(in: &cancellables)

        state.$showCamera
            .assign(to: \.showCamera, on: self)
            .store(in: &cancellables)

        state.$descriptionHint
            .assign(to: \.descriptionHint, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 處理圖片選擇
    /// - Parameter image: 選中的圖片
    func handleImageSelection(_ image: UIImage) {
        print("📸 使用者選擇了圖片，尺寸：\(image.size)")

        // 重置狀態
        clearError()
        retryCount = 0
        uploadProgress = 0.0

        state.setSelectedImage(image)
        dismissPickers()
    }

    /// 開始辨識食物
    func recognizeFood() {
        guard let image = selectedImage else {
            print("❌ 沒有選中的圖片")
            setError(.imageProcessingFailed)
            return
        }

        guard canStartRecognition else {
            print("❌ 當前無法開始辨識")
            return
        }

        Task {
            await performRecognition(image: image, hint: descriptionHint.isEmpty ? nil : descriptionHint)
        }
    }

    /// 重新辨識（智能重試 / 手動重新辨識）
    func retryRecognition() {
        guard let image = selectedImage else {
            print("❌ 沒有可重新辨識的圖片")
            return
        }

        // ✅ 若目前為成功狀態，使用者點選「重新辨識」時應直接重新執行辨識
        if recognitionStatus == .success {
            print("🔁 使用者在成功狀態下要求重新辨識，重新啟動流程")
            retryCount = 0
            isRetrying = false
            clearError()

            Task {
                await performRecognition(image: image, hint: descriptionHint.isEmpty ? nil : descriptionHint)
            }
            return
        }

        guard isErrorRetryable else {
            print("❌ 已達最大重試次數或錯誤不可重試")
            return
        }

        isRetrying = true
        retryCount += 1
        clearError()

        Task {
            // 根據錯誤類型決定重試延遲
            let delay = retryDelay(for: retryCount)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            await performRecognition(image: image, hint: descriptionHint.isEmpty ? nil : descriptionHint)
            isRetrying = false
        }
    }

    /// 顯示圖片來源選擇器
    func selectImageSource() {
        showImageSourcePicker = true
    }

    /// 顯示相機
    func showCameraAction() {
        state.showCameraView()
        showImageSourcePicker = false
    }

    /// 顯示相簿
    func showPhotoLibraryAction() {
        state.showPhotoLibrary()
        showImageSourcePicker = false
    }

    /// 清除選擇的圖片和結果
    func clearSelection() {
        uploadProgress = 0.0
        retryCount = 0
        isRetrying = false
        state.reset()
    }

    /// 清除錯誤狀態
    func clearError() {
        state.clearError()
    }

    /// 更新描述提示
    /// - Parameter hint: 新的描述提示
    func updateDescriptionHint(_ hint: String) {
        state.descriptionHint = hint
    }

    /// 隱藏所有選擇器
    func dismissPickers() {
        showImageSourcePicker = false
        state.dismissPickers()
    }

    /// 重置所有狀態（用於完全重新開始）
    func resetAll() {
        uploadProgress = 0.0
        retryCount = 0
        isRetrying = false
        showImageSourcePicker = false
        state.reset()
    }

    // MARK: - Private Methods

    /// 執行辨識流程
    /// - Parameters:
    ///   - image: 要辨識的圖片
    ///   - hint: 描述提示
    private func performRecognition(image: UIImage, hint: String?) async {
        print("🚀 開始執行食物辨識 (嘗試 \(retryCount + 1)/\(maxRetryCount + 1))")

        // 開始載入狀態
        state.setLoading()
        uploadProgress = 0.0

        do {
            // 模擬上傳進度
            await simulateUploadProgress()

            let result = try await foodRecognitionService.recognizeFood(image: image, hint: hint)

            // 成功完成
            uploadProgress = 1.0
            retryCount = 0 // 重置重試計數

            print("✅ 辨識成功")
            state.setSuccess(with: result)
            logRecognitionResult(result)

        } catch let error as FoodRecognitionError {
            print("❌ 辨識失敗：\(error)")
            handleRecognitionError(error)
        } catch {
            print("❌ 未知錯誤：\(error)")
            let recognitionError = FoodRecognitionError.unknown(error.localizedDescription)
            handleRecognitionError(recognitionError)
        }
    }

    /// 處理辨識錯誤
    /// - Parameter error: 辨識錯誤
    private func handleRecognitionError(_ error: FoodRecognitionError) {
        uploadProgress = 0.0

        // 檢查是否應該自動重試
        if shouldAutoRetry(for: error) && retryCount < maxRetryCount {
            print("🔄 將自動重試，錯誤：\(error)")
            Task {
                try? await Task.sleep(nanoseconds: UInt64(retryDelay(for: retryCount + 1) * 1_000_000_000))

                // 直接執行重新辨識，避免遞歸調用
                guard let image = selectedImage else { return }
                isRetrying = true
                retryCount += 1
                clearError()

                await performRecognition(image: image, hint: descriptionHint.isEmpty ? nil : descriptionHint)
                isRetrying = false
            }
        } else {
            // 設置錯誤狀態
            setError(error)
        }
    }

    /// 設置錯誤狀態
    /// - Parameter error: 錯誤
    private func setError(_ error: FoodRecognitionError) {
        state.setError(error)
    }

    /// 檢查是否應該自動重試
    /// - Parameter error: 錯誤
    /// - Returns: 是否應該自動重試
    private func shouldAutoRetry(for error: FoodRecognitionError) -> Bool {
        switch error {
        case .networkError, .apiError:
            return true // 網路和 API 錯誤可以自動重試
        case .imageTooLarge:
            return false // 圖片過大不應該自動重試
        case .imageProcessingFailed:
            return false // 圖片處理失敗不應該自動重試
        case .decodingError:
            return retryCount == 0 // 解碼錯誤只重試一次
        case .noResults:
            return false // 無結果不應該重試
        case .unknown:
            return retryCount == 0 // 未知錯誤只重試一次
        }
    }

    /// 計算重試延遲時間（指數退避）
    /// - Parameter attempt: 嘗試次數
    /// - Returns: 延遲時間（秒）
    private func retryDelay(for attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 10.0
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        return min(delay, maxDelay)
    }

    /// 模擬上傳進度（用於提供更好的用戶體驗）
    private func simulateUploadProgress() async {
        let totalSteps = 10
        for step in 1...totalSteps {
            uploadProgress = Double(step) / Double(totalSteps)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
        }
    }

    /// 記錄辨識結果（用於除錯和分析）
    /// - Parameter result: 辨識結果
    private func logRecognitionResult(_ result: FoodRecognitionResponse) {
        print("📊 辨識結果統計：")
        print("   - 食物數量：\(result.recognizedFoods.count)")
        print("   - 總食材數量：\(result.allIngredients.count)")
        print("   - 總設備數量：\(result.allEquipment.count)")

        if let primary = result.primaryFood {
            print("   - 主要食物：\(primary.name)")
            print("   - 主要食材：\(primary.mainIngredients.count) 個")
            print("   - 調料：\(primary.seasonings.count) 個")
            print("   - 必需設備：\(primary.essentialEquipment.count) 個")
        }

        // 記錄性能指標
        print("   - 重試次數：\(retryCount)")
        print("   - 最終進度：\(uploadProgress)")
    }
}

// MARK: - Convenience Methods
extension FoodRecognitionViewModel {

    /// 取得所有辨識出的食材
    var allIngredients: [Ingredient] {
        recognitionResult?.allIngredients ?? []
    }

    /// 取得所有辨識出的設備
    var allEquipment: [Equipment] {
        recognitionResult?.allEquipment ?? []
    }

    /// 取得食物名稱列表
    var foodNames: [String] {
        recognitionResult?.foodNames ?? []
    }

    /// 檢查是否應該顯示結果
    var shouldShowResults: Bool {
        hasResult && recognitionStatus == .success
    }

    /// 檢查是否應該顯示錯誤
    var shouldShowError: Bool {
        hasError && recognitionStatus == .error
    }

    /// 檢查是否應該顯示載入狀態
    var shouldShowLoading: Bool {
        recognitionStatus == .loading
    }

    /// 取得當前視圖狀態（用於 UI 狀態管理）
    var currentViewState: FoodRecognitionViewState {
        if shouldShowError {
            return .error(error!)
        } else if shouldShowResults {
            return .result(recognitionResult!)
        } else if shouldShowLoading {
            return .recognizing
        } else if hasSelectedImage {
            return .imageSelected
        } else {
            return .initial
        }
    }

    /// 取得重試按鈕文字
    var retryButtonTitle: String {
        if retryCount > 0 {
            return "重試 (\(retryCount)/\(maxRetryCount))"
        } else {
            return "重新辨識"
        }
    }

    /// 取得進度描述文字
    var progressDescription: String {
        if isRetrying {
            return "重試中... (\(retryCount)/\(maxRetryCount))"
        } else if recognitionStatus == .loading {
            return "辨識中"
        } else {
            return statusDescription
        }
    }

    /// 檢查是否可以選擇新圖片
    var canSelectNewImage: Bool {
        !isLoading
    }

    /// 檢查是否顯示進度條
    var shouldShowProgress: Bool {
        isLoading || uploadProgress > 0
    }
}

// MARK: - Image Processing Helpers
extension FoodRecognitionViewModel {

    /// 取得圖片資訊文字
    var imageInfoText: String {
        guard let image = selectedImage else { return "無圖片" }
        let size = image.size
        let megapixels = (size.width * size.height) / 1_000_000
        return String(format: "%.1fMP (%.0f×%.0f)", megapixels, size.width, size.height)
    }

    /// 取得預估檔案大小文字
    var estimatedFileSizeText: String {
        guard let image = selectedImage,
              let data = image.jpegData(compressionQuality: 0.7) else {
            return "未知"
        }

        let sizeInMB = Double(data.count) / (1024 * 1024)
        if sizeInMB < 1.0 {
            let sizeInKB = Double(data.count) / 1024
            return String(format: "%.0f KB", sizeInKB)
        } else {
            return String(format: "%.1f MB", sizeInMB)
        }
    }
}