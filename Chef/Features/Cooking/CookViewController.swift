//
//  CookViewController.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/7.
//


import UIKit
import SwiftUI
import AVFoundation
import Vision
import SceneKit

enum CookVoiceCommand: String, CaseIterable {
    case nextStep = "下一步"
    case previousStep = "上一步"
    case submit = "送出"
    case clear = "清除"
}
/// 「開始烹飪」AR 流程 —— 加入手勢辨識
final class CookViewController: UIViewController, ARGestureDelegate, UIGestureRecognizerDelegate {

    // MARK: - AR Session
    let gestureSession = ARSessionAdapter()

    // MARK: - Data
    let steps: [RecipeStep]
    private let stepViewModel = StepViewModel()
    private(set) var currentIndex = 0 {
        didSet {
            print("🔄 [CookViewController] currentIndex changed: \(oldValue) -> \(currentIndex)")
            updateStepLabel()
            stepViewModel.currentDescription = steps[currentIndex].description

            // 🔄 更新 stepViewModel 的當前步驟，讓 SwiftUI 自動重新創建 CookingARView
            print("📝 [CookViewController] 更新 stepViewModel.currentStepModel to step \(steps[currentIndex].step_number)")
            stepViewModel.currentStepModel = steps[currentIndex]

            // ✅ 重置手勢辨識狀態，允許新步驟重新辨識手勢
            print("🔄 [CookViewController] 重置手勢辨識狀態以支援新步驟")
            gestureSession.resetGestureState()
        }
    }

    // MARK: - UI
    private let stepLabel = UILabel()
    private let prevBtn   = UIButton(type: .system)
    private let nextBtn   = UIButton(type: .system)
    private let completeBtn = UIButton(type: .system)
    private let qaModelView = SCNView()
    private var qaTapRecognizer: UITapGestureRecognizer?
    var qaBubbleView: CookQASpeechBubbleView?
    var qaInputBubbleView: CookQAInputBubbleView?
    private var qaBubbleDismissTap: UITapGestureRecognizer?
    var pendingDraftQuestion: String = ""
    let qaWakeWord = CookAssistResourcePreloader.defaultWakeWord
    lazy var qaVoiceService = CookAssistResourcePreloader.shared.voiceService(wakeWord: qaWakeWord)
    var isVoiceDictationActive = false
    var shouldStartDictationAfterBubblePresented = false
    var baselineDictationTranscript: String?
    var lastRawDictation: String = ""
    var lastVoiceCommandExecution: (command: CookVoiceCommand, timestamp: Date)?

    // MARK: - Voice Control Helpers
    var qaCurrentStepIndex: Int { currentIndex }
    var qaStepsCount: Int { steps.count }
    func qaHasNextStep() -> Bool { currentIndex < steps.count - 1 }
    func qaHasPreviousStep() -> Bool { currentIndex > 0 }

    // 手勢狀態 UI
    private let gestureStatusLabel = UILabel()
    private let hoverProgressView  = UIProgressView()

    private var arContainer: UIHostingController<CookingARViewWrapper>!
    private var stepBinding: Binding<String>!
    private let qaService = CookQAService.shared
    private let qaRecipeContext: CookQARecipeContext?

    // 菜名（用於完成頁面）
    private var dishName: String = "料理"

    // 完成回調
    private var onComplete: (() -> Void)?

    // MARK: - Init
    init(
        steps: [RecipeStep],
        dishName: String = "料理",
        recipeContext: CookQARecipeContext? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.steps = steps
        self.dishName = dishName
        self.qaRecipeContext = recipeContext
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Cleanup
    private func cleanupARContainer() {
        print("🧹 [CookViewController.cleanupARContainer] 開始")
        guard arContainer != nil else {
            print("⚠️ [CookViewController.cleanupARContainer] arContainer 已經是 nil")
            return
        }

        // ✅ 先清空 stepViewModel 以中斷 SwiftUI 的引用鏈
        print("🧹 [CookViewController.cleanupARContainer] 清空 stepViewModel")
        stepViewModel.currentStepModel = nil
        stepViewModel.currentDescription = ""

        // 清空 stepBinding
        stepBinding = nil

        // 手動觸發 SwiftUI 的清理
        arContainer?.willMove(toParent: nil)
        arContainer?.view.removeFromSuperview()
        arContainer?.removeFromParent()
        arContainer = nil

        print("✅ [CookViewController.cleanupARContainer] 完成")
    }

    deinit {
        print("🧹 [CookViewController] deinit - 開始清理資源 (dishName: \(dishName))")

        // 確保 AR container 被清理
        cleanupARContainer()

        // 清理 gesture session
        gestureSession.removeGestureDelegate(self)
        gestureSession.setGestureEnabled(false)
        gestureSession.stop()

        print("🧹 [CookViewController] deinit - 完成")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        stepViewModel.currentDescription = steps[currentIndex].description
        stepViewModel.currentStepModel = steps[currentIndex]
        updateStepLabel()
        // ⚠️ 使用 [weak self] 避免循環引用
        stepBinding = Binding<String>(
            get: { [weak self] in
                self?.stepViewModel.currentDescription ?? ""
            },
            set: { [weak self] newValue in
                self?.stepViewModel.currentDescription = newValue
            }
        )

        // ✅ 使用 stepViewModel 來動態更新 CookingARView
        arContainer = UIHostingController(
            rootView: CookingARViewWrapper(
                stepViewModel: stepViewModel,
                sessionAdapter: gestureSession
            )
        )
        addChild(arContainer)
        arContainer.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arContainer.view)



        NSLayoutConstraint.activate([
            arContainer.view.topAnchor.constraint(equalTo: view.topAnchor),
            arContainer.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            arContainer.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arContainer.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        arContainer.didMove(toParent: self)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //print("📏 AR Container frame = \(self.arContainer.view.frame)")
        }
        // ▲ Step Label
        stepLabel.numberOfLines = 0
        stepLabel.textColor = .white
        stepLabel.font = .preferredFont(forTextStyle: .headline)
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stepLabel)
        setupQAInteractionView()
        setupQAVoiceService()

        // ▼ Prev / Next / Complete Buttons
        let navigationStack = UIStackView(arrangedSubviews: [prevBtn, nextBtn])
        navigationStack.axis = .horizontal
        navigationStack.spacing = 40
        navigationStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationStack)

        prevBtn.setTitle("〈 上一步", for: .normal)
        nextBtn.setTitle("下一步 〉", for: .normal)
        prevBtn.addTarget(self, action: #selector(prevStep), for: .touchUpInside)
        nextBtn.addTarget(self, action: #selector(nextStep), for: .touchUpInside)

        // 完成按鈕設置
        completeBtn.setTitle("✓ 完成", for: .normal)
        completeBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        completeBtn.backgroundColor = UIColor(named: "BrandOrange") ?? .systemOrange
        completeBtn.setTitleColor(.white, for: .normal)
        completeBtn.layer.cornerRadius = 12
        completeBtn.translatesAutoresizingMaskIntoConstraints = false
        completeBtn.addTarget(self, action: #selector(completeRecipe), for: .touchUpInside)
        completeBtn.isHidden = true

        // 將完成按鈕加入 navigationStack，這樣可以和上一步並排顯示
        navigationStack.addArrangedSubview(completeBtn)

        // 設定手勢狀態 UI
        setupGestureStatusUI()

        NSLayoutConstraint.activate([
            stepLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stepLabel.trailingAnchor.constraint(equalTo: qaModelView.leadingAnchor, constant: -12),
            stepLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            qaModelView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            qaModelView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            qaModelView.widthAnchor.constraint(equalToConstant: 56),
            qaModelView.heightAnchor.constraint(equalToConstant: 56),

            gestureStatusLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 8),
            gestureStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            gestureStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            gestureStatusLabel.heightAnchor.constraint(equalToConstant: 30),

            hoverProgressView.topAnchor.constraint(equalTo: gestureStatusLabel.bottomAnchor, constant: 4),
            hoverProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hoverProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hoverProgressView.heightAnchor.constraint(equalToConstant: 4),

            navigationStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            navigationStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        updateStepLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 確保顯示系統導航欄，以便有返回按鈕
        navigationController?.setNavigationBarHidden(false, animated: animated)
        // ✅ 先註冊 delegate 和啟用，再啟動 session
        gestureSession.addGestureDelegate(self)
        gestureSession.setGestureEnabled(true)
        gestureSession.start()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("📸 View Did Appear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("👋 [CookViewController] viewWillDisappear - isBeingDismissed=\(isBeingDismissed), isMovingFromParent=\(isMovingFromParent)")
        print("👋 [CookViewController] viewWillDisappear - navigationController.viewControllers.count=\(navigationController?.viewControllers.count ?? -1)")
        print("👋 [CookViewController] viewWillDisappear - parent=\(parent != nil)")

        dismissQABubble(animated: false)
        qaVoiceService.stop()
        isVoiceDictationActive = false
        baselineDictationTranscript = nil
        lastRawDictation = ""

        // 移除 delegate 並停用手勢辨識
        gestureSession.removeGestureDelegate(self)
        gestureSession.setGestureEnabled(false)
        gestureSession.stop()

        // ✅ 如果正在被移除（pop），立即清理 arContainer
        if isMovingFromParent {
            print("🧹 [CookViewController] 即將被 pop，開始清理 arContainer")
            cleanupARContainer()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("💤 [CookViewController] viewDidDisappear - isBeingDismissed=\(isBeingDismissed), isMovingFromParent=\(isMovingFromParent)")
        print("💤 [CookViewController] viewDidDisappear - navigationController.viewControllers.count=\(navigationController?.viewControllers.count ?? -1)")
        print("💤 [CookViewController] viewDidDisappear - parent=\(parent != nil)")

        // 🔍 檢查是否有任何強引用仍在保持這個 VC
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self != nil {
                print("⚠️ [CookViewController] 2 秒後仍未被釋放！存在記憶體洩漏")
            } else {
                print("✅ [CookViewController] 已成功釋放")
            }
        }
    }

    // MARK: - Helpers

    private func updateStepLabel() {
        guard !steps.isEmpty else { stepLabel.text = "無步驟"; return }
        let step = steps[currentIndex]
        stepLabel.text = "步驟 \(step.step_number)：\(step.title)\n\(step.description)"
        prevBtn.isEnabled = currentIndex > 0

        // 判斷是否為最後一步和第一步
        let isLastStep = currentIndex == steps.count - 1
        let isFirstStep = currentIndex == 0

        // 第一步：上一步隱藏，下一步顯示
        // 中間步驟：上一步和下一步都顯示
        // 最後一步：上一步和完成都顯示
        prevBtn.isHidden = isFirstStep
        nextBtn.isHidden = isLastStep
        nextBtn.isEnabled = currentIndex < steps.count - 1
        completeBtn.isHidden = !isLastStep
    }

    @objc func prevStep() {
        goToStep(currentIndex - 1)
    }

    @objc func nextStep() {
        goToStep(currentIndex + 1)
    }

    func goToStep(_ index: Int) {
        guard index != currentIndex else { return }
        guard steps.indices.contains(index) else { return }

        let direction = index > currentIndex ? "➡️" : "⬅️"
        print("\(direction) [CookViewController] goToStep: \(currentIndex) -> \(index)")
        currentIndex = index
    }

    @objc private func completeRecipe() {
        // 顯示完成頁面
        let completionView = RecipeCompletionView(
            dishName: dishName,
            totalSteps: steps.count
        ) { [weak self] in
            guard let self = self else { return }

            // 先關閉 modal 完成頁面
            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }

                // 呼叫完成回調，通知 coordinator 處理返回首頁邏輯
                self.onComplete?()
            }
        }

        let hostingController = UIHostingController(rootView: completionView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }

    private func setupQAInteractionView() {
        qaModelView.translatesAutoresizingMaskIntoConstraints = false
        qaModelView.backgroundColor = .clear
        qaModelView.scene = SCNScene()
        qaModelView.autoenablesDefaultLighting = true
        qaModelView.allowsCameraControl = false
        qaModelView.isUserInteractionEnabled = true
        qaModelView.accessibilityLabel = "烹飪求助"

        let tap = UITapGestureRecognizer(target: self, action: #selector(askCookQuestionTapped))
        qaModelView.addGestureRecognizer(tap)
        qaTapRecognizer = tap

        view.addSubview(qaModelView)
        loadQAInteractionModel()
        setQAInteractionEnabled(true)
    }

    private func loadQAInteractionModel() {
        Task { [weak self] in
            guard let self else { return }
            let scene = await CookAssistResourcePreloader.shared.qaInteractionScene()
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let scene else {
                    print("⚠️ [CookViewController] 無法載入 firebaby.usdz 資源")
                    return
                }
                self.qaModelView.scene = scene
                self.qaModelView.scene?.background.contents = UIColor.clear
                self.qaModelView.pointOfView = self.makeQAInteractionCameraIfNeeded(for: scene)
            }
        }
    }

    private func makeQAInteractionCameraIfNeeded(for scene: SCNScene) -> SCNNode? {
        if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
            return cameraNode
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 2.5)
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
    }

    private func setQAInteractionEnabled(_ enabled: Bool) {
        qaModelView.isUserInteractionEnabled = enabled
        qaModelView.alpha = enabled ? 1.0 : 0.5
    }

    func dismissQABubble(animated: Bool = true, persistDraft: Bool = true) {
        let answerBubble = qaBubbleView
        let inputBubble = qaInputBubbleView
        guard answerBubble != nil || inputBubble != nil else { return }

        qaBubbleView = nil
        qaInputBubbleView = nil

        let viewsToDismiss = [answerBubble, inputBubble].compactMap { $0 }

        let animations = {
            viewsToDismiss.forEach { view in
                view.alpha = 0
                view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
        }

        let completion: (Bool) -> Void = { [weak self] _ in
            if let input = inputBubble {
                input.resignFocus()
                if persistDraft {
                    self?.pendingDraftQuestion = input.currentDraftText()
                }
            }
            viewsToDismiss.forEach { $0.removeFromSuperview() }
            self?.removeBubbleDismissGesture()
            self?.shouldStartDictationAfterBubblePresented = false
            self?.baselineDictationTranscript = nil
            if let existing = self?.pendingDraftQuestion, !existing.isEmpty {
                print("🗣️ [QAVoiceService] Current transcription: \(existing)")
            }
            self?.lastRawDictation = ""
            if let self = self, self.isVoiceDictationActive {
                self.qaVoiceService.cancelDictationAndResumeKeywordListening()
                self.isVoiceDictationActive = false
            } else {
                self?.qaVoiceService.startKeywordListening()
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
        if !persistDraft {
            pendingDraftQuestion = ""
        }
    }

    private func installBubbleDismissGestureIfNeeded() {
        guard qaBubbleDismissTap == nil else { return }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapped))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
        qaBubbleDismissTap = recognizer
    }

    private func removeBubbleDismissGesture() {
        guard let recognizer = qaBubbleDismissTap else { return }
        view.removeGestureRecognizer(recognizer)
        qaBubbleDismissTap = nil
    }

    @objc private func askCookQuestionTapped() {
        guard !steps.isEmpty else { return }
        showQAInputBubble()
    }

    private func submitCookQuestion(_ question: String) {
        let description = steps[currentIndex].description

        guard let screenshot = captureARScreenshot() else {
            presentQAError(message: "目前無法擷取相機畫面，請稍後再試。")
            return
        }

        dismissQABubble(persistDraft: false)

        guard let base64Image = ImageCompressor.compressToBase64(image: screenshot) else {
            presentQAError(message: "圖片處理失敗，請稍後再試。")
            return
        }

        setQAInteractionEnabled(false)

        let registryContext = CookRecipeContextRegistry.shared.context(matching: steps)
        let effectiveRecipeContext: CookQARecipeContext = qaRecipeContext
            ?? registryContext
            ?? CookQARecipeContext.fallback(
                dishName: dishName,
                steps: steps
            )

        print("📨 [CookQA] 發送問題")
        print("    • Question: \(question)")
        print("    • Step description: \(description)")
        print("    • Has recipe context: \(qaRecipeContext != nil)")
        print("    • Registry context matched: \(registryContext != nil)")
        print("    • Recipe prompt: \(effectiveRecipeContext.sanitizedPromptSnippet())")

        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await qaService.askCookAssistant(
                    question: question,
                    stepDescription: description,
                    base64Image: base64Image,
                    recipeContext: effectiveRecipeContext
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setQAInteractionEnabled(true)
                    self.presentQAAnswer(response.answer)
                    self.qaVoiceService.startKeywordListening()
                }
                print("✅ [CookQA] 成功取得回覆")
            } catch {
                let message: String
                if let error = error as? CookQAServiceError {
                    message = error.errorDescription ?? "發生未知錯誤"
                } else {
                    message = error.localizedDescription
                }

                print("❌ [CookQA] 發送失敗 - \(message)")

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.setQAInteractionEnabled(true)
                    self.presentQAError(message: message)
                    self.qaVoiceService.startKeywordListening()
                }
            }
        }
    }

    private func captureARScreenshot() -> UIImage? {
        guard let containerView = arContainer?.view else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: containerView.bounds)
        return renderer.image { _ in
            containerView.drawHierarchy(in: containerView.bounds, afterScreenUpdates: true)
        }
    }

    func showQAInputBubble(voiceTriggered: Bool = false) {
        dismissQABubble(animated: false)

        let bubble = CookQAInputBubbleView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)

        bubble.onSubmit = { [weak self, weak bubble] text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                bubble?.showValidationError("請輸入想詢問的問題內容。")
                return
            }
            self?.qaVoiceService.cancelDictationAndResumeKeywordListening()
            self?.isVoiceDictationActive = false
            self?.baselineDictationTranscript = nil
            self?.lastRawDictation = ""
            self?.submitCookQuestion(trimmed)
        }
        bubble.onClear = { [weak self] in
            guard let self else { return }
            pendingDraftQuestion = ""
            baselineDictationTranscript = nil
            lastRawDictation = ""
        }

        view.addSubview(bubble)
        qaInputBubbleView = bubble
        shouldStartDictationAfterBubblePresented = voiceTriggered
        if voiceTriggered {
            baselineDictationTranscript = nil
            lastRawDictation = ""
        }
        installBubbleDismissGestureIfNeeded()

        let constraints = [
            bubble.trailingAnchor.constraint(equalTo: qaModelView.leadingAnchor, constant: -12),
            bubble.centerYAnchor.constraint(equalTo: qaModelView.centerYAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 240),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16)
        ]
        constraints.last?.priority = .defaultHigh
        NSLayoutConstraint.activate(constraints)

        view.layoutIfNeeded()

        bubble.setDraftText(pendingDraftQuestion)

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut]
        ) {
            bubble.alpha = 1
            bubble.transform = .identity
        } completion: { [weak bubble, weak self] _ in
            bubble?.focus()
            self?.beginVoiceDictationIfNeededAfterBubble()
        }
    }

    private func presentQAAnswer(_ answer: String) {
        dismissQABubble(animated: false, persistDraft: false)

        let bubble = CookQASpeechBubbleView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.configure(text: answer)
        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)

        let tapToDismiss = UITapGestureRecognizer(target: self, action: #selector(handleBubbleTapped))
        bubble.addGestureRecognizer(tapToDismiss)

        view.addSubview(bubble)
        qaBubbleView = bubble
        installBubbleDismissGestureIfNeeded()

        let constraints = [
            bubble.trailingAnchor.constraint(equalTo: qaModelView.leadingAnchor, constant: -12),
            bubble.centerYAnchor.constraint(equalTo: qaModelView.centerYAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16)
        ]
        constraints.last?.priority = .defaultHigh
        NSLayoutConstraint.activate(constraints)

        view.layoutIfNeeded()

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut]
        ) {
            bubble.alpha = 1
            bubble.transform = .identity
        }
    }

    @objc private func handleBubbleTapped() {
        dismissQABubble()
    }

    @objc private func handleBackgroundTapped() {
        dismissQABubble()
    }

    private func presentQAError(message: String) {
        let alert = UIAlertController(title: "送出失敗", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }











    // MARK: - 手勢狀態 UI
    private func setupGestureStatusUI() {
        gestureStatusLabel.text = "手勢辨識：準備中"
        gestureStatusLabel.textColor = .white
        gestureStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        gestureStatusLabel.textAlignment = .center
        gestureStatusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        gestureStatusLabel.layer.cornerRadius = 8
        gestureStatusLabel.clipsToBounds = true
        gestureStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gestureStatusLabel)

        hoverProgressView.progressTintColor = .systemBlue
        hoverProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        hoverProgressView.progress = 0.0
        hoverProgressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hoverProgressView)
    }

    private func updateGestureStatusUI(_ state: GestureState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let (text, color): (String, UIColor) = {
                switch state {
                case .idle:       return ("手勢辨識：等待手部", .systemGray)
                case .detecting:  return ("手勢辨識：偵測中", .systemYellow)
                case .hovering:   return ("手勢辨識：懸停中…", .systemOrange)
                case .ready:      return ("手勢辨識：準備完成", .systemGreen)
                case .processing: return ("手勢辨識：處理中", .systemBlue)
                case .completed:  return ("手勢辨識：完成", .systemGreen)
                }
            }()
            self.gestureStatusLabel.text = text
            self.gestureStatusLabel.backgroundColor = color.withAlphaComponent(0.6)
        }
    }

    private func updateHoverProgressUI(_ progress: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.hoverProgressView.progress = max(0, min(progress, 1))
        }
    }

    func presentToast(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let toastLabel = UILabel()
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            toastLabel.text = message
            toastLabel.textColor = .white
            toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
            toastLabel.textAlignment = .center
            toastLabel.numberOfLines = 0
            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            toastLabel.alpha = 0
            toastLabel.layer.cornerRadius = 12
            toastLabel.clipsToBounds = true

            let horizontalPadding: CGFloat = 24
            let verticalPadding: CGFloat = 12

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = .clear
            container.addSubview(toastLabel)

            self.view.addSubview(container)

            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: horizontalPadding),
                container.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -horizontalPadding),
                container.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -verticalPadding),

                toastLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                toastLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                toastLabel.topAnchor.constraint(equalTo: container.topAnchor),
                toastLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            self.view.layoutIfNeeded()

            UIView.animate(withDuration: 0.25, animations: {
                toastLabel.alpha = 1
            }) { _ in
                UIView.animate(
                    withDuration: 0.25,
                    delay: 1.5,
                    options: [.curveEaseInOut],
                    animations: {
                        toastLabel.alpha = 0
                    }, completion: { _ in
                        container.removeFromSuperview()
                    }
                )
            }
        }
    }
}

// MARK: - CookingARViewWrapper
/// SwiftUI Wrapper，讓 CookingARView 根據 stepViewModel 自動更新
private struct CookingARViewWrapper: View {
    @ObservedObject var stepViewModel: StepViewModel
    let sessionAdapter: ARSessionAdapter

    var body: some View {
        Group {
            if let stepModel = stepViewModel.currentStepModel {
                CookingARView(
                    stepModel: stepModel,
                    sessionAdapter: sessionAdapter
                )
                // ✅ 移除 .id() - 讓 SwiftUI 重用同一個 UIView，只透過 updateUIView 更新
                // 這樣可以避免每次切換步驟都重新創建 ARView，減少記憶體消耗
            }
        }
    }
}

// MARK: - ARGestureDelegate
extension CookViewController {
    func didRecognizeGesture(_ gestureType: GestureType) {
        print("🎯 [CookViewController] 接收到手勢: \(gestureType.description)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch gestureType {
            case .previousStep:
                self.prevStep()
            case .nextStep:
                // 如果在最後一步，「下一步」手勢應該進入完成頁面
                if self.currentIndex == self.steps.count - 1 {
                    print("✅ [CookViewController] 最後一步手勢觸發，進入完成頁面")
                    self.completeRecipe()
                } else {
                    self.nextStep()
                }
            }
        }
    }

    func gestureStateDidChange(_ state: GestureState) {
        print("🎯 [CookViewController] 手勢狀態變更: \(state.description)")
        updateGestureStatusUI(state)
    }

    func hoverProgressDidUpdate(_ progress: Float) {
        updateHoverProgressUI(progress)
    }

    func palmStateDidChange(_ palmState: PalmState) {
        // 目前僅示意；若需要可在這裡更新額外 UI 或紀錄
        // print("✋ palm state: \(palmState)")
    }

    func gestureRecognitionDidFail(with error: GestureRecognitionError) {
        print("❌ [CookViewController] 手勢辨識錯誤: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.gestureStatusLabel.text = "手勢辨識錯誤：\(error.localizedDescription)"
            self?.gestureStatusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CookViewController {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let bubble = qaBubbleView, let touchedView = touch.view, touchedView.isDescendant(of: bubble) {
            return false
        }
        if let inputBubble = qaInputBubbleView, let touchedView = touch.view, touchedView.isDescendant(of: inputBubble) {
            return false
        }
        return true
    }
}
