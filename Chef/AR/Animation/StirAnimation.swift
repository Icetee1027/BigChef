import Foundation
import simd
import RealityKit

/// 攪拌（Stir）動畫：在容器偵測後，在容器內部位置執行攪拌動作
class StirAnimation: Animation {
    private let container: Container
    private let ingredient: String?
    private let model: Entity
    private var boundingBoxRect: CGRect?

    init(container: Container,
         ingredient: String? = nil,
         scale: Float = 1.0,
         isRepeat: Bool = true) {
        self.container = container
        self.ingredient = ingredient
        let url = Bundle.main.url(forResource: "stir", withExtension: "usdz")!
        if let cached = try? AnimationModelCache.entity(for: url) {
            model = cached
        } else {
            model = ModelEntity()
        }
        super.init(type: .stir, scale: scale, isRepeat: isRepeat)
    }

    override var requiresContainerDetection: Bool { true }
    override var containerType: Container? { container }

    /// 當父類的 play 被呼叫時，自動注入到 Anchor 上並播放動畫
    override func applyAnimation(to anchor: AnchorEntity, on arView: ARView) {
        let horizontalOffset: Float = 0.05
        let forwardOffset: Float = -1.0
        let verticalOffset: Float = -0.5

        let instance = model.clone(recursive: true)
        instance.scale = SIMD3<Float>(repeating: scale)
        instance.position.x += horizontalOffset
        instance.position.z += forwardOffset
        instance.position.y += verticalOffset
        if let name = ingredient, !name.isEmpty {
            let bounds = instance.visualBounds(relativeTo: instance)
            _ = ARText.addLabel(
                text: name,
                to: instance,
                padding: 0.18,
                boundingOverride: bounds,
                scaleMultiplier: 1.25
            )
        }
        anchor.addChild(instance)
        if let res = instance.availableAnimations.first {
            let resource = res.repeat(duration: .infinity)
            instance.playAnimation(resource,
                                   transitionDuration: 0.2,
                                   startsPaused: false)
        }
    }

    /// 每次物件偵測框更新時記錄，實際定位由 Coordinator 處理
    override func updateBoundingBox(rect: CGRect) {
        boundingBoxRect = rect
    }
}
