//
//  QABubbleViews.swift
//  ChefHelper
//
//  Created by Codex on 2025/05/08.
//

import UIKit

final class CookQAInputBubbleView: UIView, UITextViewDelegate {
    var onSubmit: ((String) -> Void)?
    var onClear: (() -> Void)?

    private let containerView = UIView()
    private let tailView = SpeechBubbleTailView()
    private let titleLabel = UILabel()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private var textViewHeightConstraint: NSLayoutConstraint?

    private let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 18
        containerView.layer.borderColor = UIColor.black.cgColor
        containerView.layer.borderWidth = 2
        containerView.layer.shadowColor = UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 0.6).cgColor
        containerView.layer.shadowOpacity = 0.6
        containerView.layer.shadowRadius = 6
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.masksToBounds = false
        addSubview(containerView)

        tailView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tailView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Question❓"
        titleLabel.textColor = .black
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor(white: 0.97, alpha: 1)
        textView.layer.cornerRadius = 12
        textView.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        textView.layer.borderWidth = 1
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .black
        textView.tintColor = .systemBlue
        textView.keyboardAppearance = .light
        textView.returnKeyType = .send
        textView.isScrollEnabled = false
        textView.delegate = self

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = ""
        placeholderLabel.textColor = UIColor.black.withAlphaComponent(0.3)
        placeholderLabel.font = .systemFont(ofSize: 15)
        textView.addSubview(placeholderLabel)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setTitle("清除", for: .normal)
        clearButton.setTitleColor(UIColor.systemRed, for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        clearButton.layer.cornerRadius = 12
        clearButton.layer.borderWidth = 1
        clearButton.layer.borderColor = UIColor.systemRed.cgColor
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.title = "清除"
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
            configuration.baseForegroundColor = UIColor.systemRed
            clearButton.configuration = configuration
        } else {
            clearButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        }
        clearButton.addTarget(self, action: #selector(handleClearTapped), for: .touchUpInside)
        clearButton.isEnabled = false
        clearButton.alpha = 0.5

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("送出", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        sendButton.backgroundColor = UIColor.systemBlue
        sendButton.layer.cornerRadius = 12
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.filled()
            configuration.title = "送出"
            configuration.baseBackgroundColor = UIColor.systemBlue
            configuration.baseForegroundColor = .white
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 22, bottom: 10, trailing: 22)
            sendButton.configuration = configuration
        } else {
            sendButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 22, bottom: 10, right: 22)
        }
        sendButton.addTarget(self, action: #selector(handleSendTapped), for: .touchUpInside)
        sendButton.isEnabled = false
        sendButton.alpha = 0.5

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textColor = UIColor.systemRed
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        containerView.addSubview(titleLabel)
        containerView.addSubview(textView)
        containerView.addSubview(errorLabel)
        containerView.addSubview(clearButton)
        containerView.addSubview(sendButton)

        let minimumWidth = max(168, sendButton.intrinsicContentSize.width + contentInsets.left + contentInsets.right)
        let widthConstraint = containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth)
        widthConstraint.priority = .required

        let errorBottom = errorLabel.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -12)
        errorBottom.priority = .defaultHigh

        textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            widthConstraint,

            tailView.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            tailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            tailView.widthAnchor.constraint(equalToConstant: 26),
            tailView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: contentInsets.left),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentInsets.right),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: contentInsets.top),

            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: contentInsets.left),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentInsets.right),
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textViewHeightConstraint!,

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),

            errorLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor),
            errorLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 6),
            errorBottom,

            clearButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            clearButton.leadingAnchor.constraint(greaterThanOrEqualTo: textView.leadingAnchor),
            clearButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -contentInsets.bottom),
            clearButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),

            sendButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentInsets.right),
            sendButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -contentInsets.bottom)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        updateSendButtonState()
    }

    func focus() {
        textView.becomeFirstResponder()
    }

    func resignFocus() {
        textView.resignFirstResponder()
    }

    var isInputActive: Bool {
        textView.isFirstResponder
    }

    func setDraftText(_ text: String) {
        textView.text = text
        placeholderLabel.isHidden = !text.isEmpty
        clearValidationError()
        updateSendButtonState()
        resizeTextViewIfNeeded()
    }

    func currentDraftText() -> String {
        textView.text ?? ""
    }

    func showValidationError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        sendButton.shake()
    }

    func clearValidationError() {
        errorLabel.isHidden = true
    }

    @objc private func handleSendTapped() {
        clearValidationError()
        onSubmit?(textView.text)
    }

    @objc private func handleClearTapped() {
        onClear?()
        textView.text = ""
        placeholderLabel.isHidden = false
        clearValidationError()
        updateSendButtonState()
        resizeTextViewIfNeeded()
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSendButtonState()
        if sendButton.isEnabled {
            clearValidationError()
        }
        resizeTextViewIfNeeded()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            handleSendTapped()
            return false
        }
        return true
    }

    func updateSendButtonState() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasText
        sendButton.alpha = hasText ? 1.0 : 0.5
        clearButton.isEnabled = hasText
        clearButton.alpha = hasText ? 1.0 : 0.5
    }

    private func resizeTextViewIfNeeded() {
        guard let heightConstraint = textViewHeightConstraint else { return }
        let minHeight: CGFloat = 44
        let maxHeight: CGFloat = 140
        let fittingSize = CGSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        var targetHeight = textView.sizeThatFits(fittingSize).height
        if targetHeight.isNaN || targetHeight.isInfinite {
            targetHeight = minHeight
        }
        targetHeight = max(minHeight, min(targetHeight, maxHeight))
        if abs(heightConstraint.constant - targetHeight) > 0.5 {
            heightConstraint.constant = targetHeight
            textView.isScrollEnabled = targetHeight >= maxHeight
            UIView.animate(withDuration: 0.15) {
                self.layoutIfNeeded()
            }
        }
    }
}

final class CookQASpeechBubbleView: UIView {
    private let containerView = UIView()
    private let textLabel = UILabel()
    private let tailView = SpeechBubbleTailView()

    private let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 18
        containerView.layer.borderColor = UIColor.black.cgColor
        containerView.layer.borderWidth = 2
        containerView.layer.masksToBounds = false
        containerView.layer.shadowColor = UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 0.6).cgColor
        containerView.layer.shadowOpacity = 0.6
        containerView.layer.shadowRadius = 6
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textColor = .black
        textLabel.font = .systemFont(ofSize: 16, weight: .medium)
        textLabel.numberOfLines = 0

        tailView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)
        addSubview(tailView)
        containerView.addSubview(textLabel)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            tailView.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            tailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            tailView.widthAnchor.constraint(equalToConstant: 26),
            tailView.heightAnchor.constraint(equalToConstant: 20),

            textLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: contentInsets.left),
            textLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentInsets.right),
            textLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: contentInsets.top),
            textLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -contentInsets.bottom)
        ])
    }

    func configure(text: String) {
        textLabel.text = text
    }
}

private final class SpeechBubbleTailView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        backgroundColor = .clear
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)

        layer.shadowColor = UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 0.6).cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height

        path.move(to: CGPoint(x: 0, y: height * 0.15))
        path.addQuadCurve(to: CGPoint(x: width, y: height / 2), controlPoint: CGPoint(x: width * 0.35, y: height * 0.1))
        path.addQuadCurve(to: CGPoint(x: 0, y: height * 0.85), controlPoint: CGPoint(x: width * 0.35, y: height * 0.9))
        path.close()

        shapeLayer.path = path.cgPath
        layer.shadowPath = path.cgPath
    }
}

extension UIView {
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.3
        animation.values = [-6, 6, -4, 4, -2, 2, 0]
        layer.add(animation, forKey: "shake")
    }
}

