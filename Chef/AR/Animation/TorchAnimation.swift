import Foundation
import simd
import RealityKit

class TorchAnimation: Animation {
    private let torch: Entity
    private var torchPosition: SIMD3<Float>?

    init(torchPosition: SIMD3<Float>? = nil, scale: Float = 1.0, isRepeat: Bool = false) {
        self.torchPosition = torchPosition
        guard let url = Bundle.main.url(forResource: "torch", withExtension: "usdz") else {
            fatalError("❌ 找不到 torch.usdz")
        }
        do {
            torch = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 torch.usdz：\(error)")
        }
        super.init(type: .torch, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        let entity = torch
        guard let pos = torchPosition else {
            print("⚠️ 未設定 torchPosition，無法播放 torch 動畫")
            return
        }
        let anchor = AnchorEntity(world: pos)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        if let animation = entity.availableAnimations.first {
            let resource = isRepeat
                ? animation.repeat(duration: .infinity)
                : animation
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：torch")
        }
    }
}
