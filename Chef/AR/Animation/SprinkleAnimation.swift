import Foundation
import simd
import RealityKit

class SprinkleAnimation: Animation {
    private let sprinkle: Entity
    private let container: Container
    private var containerPosition: SIMD3<Float>?
    private var sprinklePosition: SIMD3<Float>?

    init(container: Container, scale: Float = 1.0, isRepeat: Bool = false) {
        self.container = container
        guard let url = Bundle.main.url(forResource: "sprinkle", withExtension: "usdz") else {
            fatalError("❌ 找不到 sprinkle.usdz")
        }
        do {
            sprinkle = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 sprinkle.usdz：\(error)")
        }
        super.init(type: .sprinkle, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        guard let pos = sprinklePosition else {
            print("⚠️ 未設定 sprinklePosition，無法播放 sprinkle 動畫")
            return
        }
        let entity = sprinkle
        let anchor = AnchorEntity(world: pos)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        if let animation = entity.availableAnimations.first {
            let resource = isRepeat
                ? animation.repeat(duration: .infinity)
                : animation
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：sprinkle")
        }
    }
}
