import Foundation
import simd
import RealityKit

class PeelAnimation: Animation {
    private let peel: Entity
    private var peelPosition: SIMD3<Float>?
    
    init(peelPosition: SIMD3<Float>? = nil, scale: Float = 1.0, isRepeat: Bool = false) {
        self.peelPosition = peelPosition
        guard let url = Bundle.main.url(forResource: "peel", withExtension: "usdz") else {
            fatalError("❌ 找不到 peel.usdz")
        }
        do {
            peel = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 peel.usdz：\(error)")
        }
        super.init(type: .peel, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        let entity = peel
        guard let pos = peelPosition else {
            print("⚠️ 未設定 peelPosition，無法播放 peel 動畫")
            return
        }
        let anchor = AnchorEntity(world: pos)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        if let animation = entity.availableAnimations.first {
            let resource = isRepeat ? animation.repeat(duration: .infinity) : animation
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：peel")
        }
    }
}
