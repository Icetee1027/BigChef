// CookViewController+Gestures.swift
// ChefHelper
//
// 手勢相關：AR 手勢代理 + UIKit 基本滑動/點擊
//

import UIKit
import ARKit

// 如果你的專案裡有自定義 ARGestureDelegate / ARSessionAdapter，這裡實作對應的代理方法。
// 請確保 CookViewController 裡的 nextStep()/prevStep()/goToStep(_:) 不是 private。
extension CookViewController: ARGestureDelegate, UIGestureRecognizerDelegate {

    // MARK: - Install
    /// 主控制器在 viewDidLoad() 內呼叫
    func installGestures() {
        // 把 AR 手勢事件回傳給自己
        gestureSession.delegate = self

        // MARK: UIKit 補充手勢（左右滑動 + 點擊）
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeLeft))
        swipeLeft.direction = .left
        swipeLeft.delegate = self
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeRight))
        swipeRight.direction = .right
        swipeRight.delegate = self
        view.addGestureRecognizer(swipeRight)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    // MARK: - UIKit Gesture Actions
    @objc private func onSwipeLeft() {
        // 下一步
        nextStep()
        presentToast("下一步")
    }

    @objc private func onSwipeRight() {
        // 上一步
        prevStep()
        presentToast("上一步")
    }

    @objc private func onTap() {
        // 你可以選擇：重播動畫 / 顯示提示 / 切換 UI
        presentToast("已點擊畫面")
    }

    // MARK: - UIGestureRecognizerDelegate（如需與其他手勢共存可調整策略）
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允許同時辨識（依專案需求調整）
        return true
    }

    // MARK: - ARGestureDelegate（依你的 ARSessionAdapter 介面調整）
    /// 兩指縮放
    func didDetectPinch(scale: CGFloat, state: UIGestureRecognizer.State) {
        // 例：把縮放傳給 ARSessionAdapter 去操作目前模型
        // gestureSession.applyScale(scale, state: state)
        // 這裡保留空實作，避免硬依賴；之後可依需求填入
    }

    /// 兩指旋轉
    func didDetectRotation(rotation: CGFloat, state: UIGestureRecognizer.State) {
        // gestureSession.applyRotation(rotation, state: state)
    }

    /// 一指平移（螢幕座標）
    func didDetectPan(translation: CGPoint, state: UIGestureRecognizer.State) {
        // gestureSession.applyTranslation(translation, state: state)
    }

    /// 點擊選取（如 AR 物件點擊）
    func didDetectTap(at point: CGPoint) {
        // 可用 hitTest 轉世界座標，或觸發 UI
        // presentToast("AR 點擊：(\(Int(point.x)), \(Int(point.y)))")
    }

    /// 自由擴充：若你的 ARSessionAdapter 還有其他 delegate 事件，於此加上
    /// 例如：容器偵測完成 / 目標對齊更新 / 錯誤提示等。
    func didUpdateFocusEntity(isTracking: Bool) {
        // 追蹤狀態可驅動提示或引導
        // presentToast(isTracking ? "已追蹤" : "遺失追蹤")
    }
}

