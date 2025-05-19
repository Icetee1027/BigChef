import Foundation
import simd
import RealityKit

class CutAnimation: Animation {
    private let cut: Entity
    private var cutPosition: SIMD3<Float>?

    init(cutPosition: SIMD3<Float>? = nil, scale: Float = 1.0, isRepeat: Bool = false) {
        guard let url = Bundle.main.url(forResource: "cut", withExtension: "usdz") else {
            fatalError("❌ 找不到 cut.usdz")
        }
        do {
            cut = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 cut.usdz：\(error)")
        }
        self.cutPosition = cutPosition
        super.init(type: .cut, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        let entity = cut
        guard let cutPosition = cutPosition else {
            print("⚠️ 未設定 cutPosition，無法播放 cut 動畫")
            return
        }
        let anchor = AnchorEntity(world: cutPosition)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        if let animation = entity.availableAnimations.first {
            let resource = isRepeat
                ? animation.repeat(duration: .infinity)
                : animation
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：cut")
        }
    }
}
