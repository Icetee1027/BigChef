import UIKit
import QuartzCore

@MainActor
final class CookLoadingViewController: UIViewController {
    private let steps: [RecipeStep]
    private let dishName: String
    var onReady: (([RecipeStep]) -> Void)?
    var onFailed: ((Error) -> Void)?

    private let gradientLayer = CAGradientLayer()
    private let glowView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let dishLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressStack = UIStackView()
    private var progressSteps: [LoadingStepView] = []
    private var hasStarted = false

    init(steps: [RecipeStep], dishName: String) {
        self.steps = steps
        self.dishName = dishName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureContent()
        configureProgressStack()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 確保顯示系統導航欄，以便有返回按鈕
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        glowView.layer.cornerRadius = glowView.bounds.width / 2
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true

        Task { [weak self] in
            guard let self else { return }
            await self.runLoadingSequence()
            if Task.isCancelled { return }
            self.onReady?(self.steps)
        }
    }

    private func configureBackground() {
        view.backgroundColor = .black
        gradientLayer.colors = [
            UIColor(red: 25/255, green: 24/255, blue: 31/255, alpha: 1).cgColor,
            UIColor(red: 13/255, green: 11/255, blue: 18/255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)

        let colorAnimation = CABasicAnimation(keyPath: "colors")
        colorAnimation.fromValue = gradientLayer.colors
        colorAnimation.toValue = [
            UIColor(red: 38/255, green: 29/255, blue: 58/255, alpha: 1).cgColor,
            UIColor(red: 19/255, green: 13/255, blue: 33/255, alpha: 1).cgColor
        ]
        colorAnimation.duration = 4
        colorAnimation.autoreverses = true
        colorAnimation.repeatCount = .greatestFiniteMagnitude
        gradientLayer.add(colorAnimation, forKey: "gradientPulse")
    }

    private func configureContent() {
        glowView.translatesAutoresizingMaskIntoConstraints = false
        glowView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.25)
        view.addSubview(glowView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        dishLabel.translatesAutoresizingMaskIntoConstraints = false
        dishLabel.text = dishName
        dishLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        dishLabel.textColor = .white
        dishLabel.textAlignment = .center
        view.addSubview(dishLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "正在喚醒烹飪助理…"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "正在準備 AR 動畫資源…"
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            glowView.widthAnchor.constraint(equalToConstant: 160),
            glowView.heightAnchor.constraint(equalTo: glowView.widthAnchor),
            glowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            activityIndicator.centerXAnchor.constraint(equalTo: glowView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: glowView.centerYAnchor),

            dishLabel.bottomAnchor.constraint(equalTo: glowView.topAnchor, constant: -40),
            dishLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            dishLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: dishLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: dishLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: dishLabel.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: dishLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: dishLabel.trailingAnchor)
        ])

        startGlowAnimation()
    }

    private func configureProgressStack() {
        progressStack.axis = .vertical
        progressStack.spacing = 12
        progressStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressStack)

        let steps: [String] = [
            "載入AR",
            "手勢偵測啟動中",
            "載入Ari 阿里語音助理"
        ]

        progressSteps = steps.map { title in
            let view = LoadingStepView(title: title)
            progressStack.addArrangedSubview(view)
            return view
        }

        NSLayoutConstraint.activate([
            progressStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 32),
            progressStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            progressStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func startGlowAnimation() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.85
        scale.toValue = 1.1
        scale.duration = 1.4
        scale.autoreverses = true
        scale.repeatCount = .greatestFiniteMagnitude
        glowView.layer.add(scale, forKey: "scalePulse")

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.25
        opacity.toValue = 0.6
        opacity.duration = 1.4
        opacity.autoreverses = true
        opacity.repeatCount = .greatestFiniteMagnitude
        glowView.layer.add(opacity, forKey: "opacityPulse")
    }

    private func runLoadingSequence() async {
        let operations: [LoadingOperation] = [
            LoadingOperation(title: "載入AR…") { [weak self] in
                guard let self else { return }
                await self.preloadAnimationAssets(for: self.steps)
            },
            LoadingOperation(title: "手勢偵測啟動中…") {
                await CookAssistResourcePreloader.shared.preloadGestureControl()
            },
            LoadingOperation(title: "載入Ari 阿里語音助理…") {
                async let qaResources: Void = CookAssistResourcePreloader.shared.preloadQAInteractionResources()
                async let voiceControl: Void = CookAssistResourcePreloader.shared.preloadVoiceControl(
                    wakeWord: CookAssistResourcePreloader.defaultWakeWord
                )
                await qaResources
                await voiceControl
            }
        ]

        for (index, operation) in operations.enumerated() {
            statusLabel.text = operation.title
            updateProgressStep(at: index, state: .active)
            await operation.action()
            updateProgressStep(at: index, state: .completed)
        }

        statusLabel.text = "準備完成，即將為您開啟 AR 烹飪體驗！"
    }

    private func updateProgressStep(at index: Int, state: LoadingStepView.State) {
        guard progressSteps.indices.contains(index) else { return }
        for (idx, stepView) in progressSteps.enumerated() {
            if idx < index {
                stepView.updateState(.completed)
            } else if idx == index {
                stepView.updateState(state)
            } else if stepView.currentState != .pending {
                stepView.updateState(.pending)
            }
        }
    }

    private func preloadAnimationAssets(for steps: [RecipeStep]) async {
        let items = steps.compactMap { step -> (AnimationType, AnimationParams)? in
            guard let apiType = step.arType,
                  let params = step.arParameters,
                  let animType = AnimationType(rawValue: apiType.rawValue) else {
                return nil
            }

            let containerEnum: Container? = params.container.flatMap { Container(rawValue: $0) }
            let converted = AnimationParams(
                coordinate:  params.coordinate?.map { Float($0) },
                container:   containerEnum,
                ingredient:  params.ingredient,
                color:       params.color,
                time:        params.time.map { Float($0) },
                temperature: params.temperature.map { Float($0) },
                flameLevel:  params.flameLevel
            )

            return (animType, converted)
        }

        for (type, params) in items {
            _ = AnimationFactory.make(type: type, params: params)
        }
    }
}

private struct LoadingOperation {
    let title: String
    let action: () async -> Void
}

private final class LoadingStepView: UIStackView {
    enum State {
        case pending
        case active
        case completed
    }

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private(set) var currentState: State = .pending

    init(title: String) {
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 12
        alignment = .center

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = UIColor.white.withAlphaComponent(0.6)
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor).isActive = true

        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        titleLabel.font = .systemFont(ofSize: 15, weight: .regular)

        addArrangedSubview(iconView)
        addArrangedSubview(titleLabel)

        updateState(.pending)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateState(_ newState: State) {
        currentState = newState
        iconView.layer.removeAnimation(forKey: "rotation")

        switch newState {
        case .pending:
            iconView.image = UIImage(systemName: "circle")
            iconView.alpha = 0.3
            iconView.tintColor = UIColor.white.withAlphaComponent(0.6)
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        case .active:
            iconView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            iconView.alpha = 0.9
            iconView.tintColor = UIColor.systemOrange
            titleLabel.textColor = UIColor.systemOrange
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.duration = 1.2
            animation.repeatCount = .greatestFiniteMagnitude
            iconView.layer.add(animation, forKey: "rotation")
        case .completed:
            iconView.image = UIImage(systemName: "checkmark.circle.fill")
            iconView.alpha = 1
            iconView.tintColor = UIColor.systemGreen
            titleLabel.textColor = UIColor.white
        }
    }
}

