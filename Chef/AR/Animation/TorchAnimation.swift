import Foundation
import simd
import RealityKit
import ARKit

/// 炙燒（Torch）動畫：不依賴容器與座標，預設放在鏡頭前方
class TorchAnimation: Animation {
    // 不需要容器偵測
    override var requiresContainerDetection: Bool { false }
    override var containerType: Container? { nil }

    private let torchModel: Entity
    private let ingredient: String?
    private let distance: Float
    private let scaleMultiplier: Float = 0.8

    init(ingredient: String? = nil,
         scale: Float,
         isRepeat: Bool = true,
         distance: Float = 0.5) {
        self.ingredient = ingredient
        self.distance = distance

        // 載入 torch.usdz
        guard let url = Bundle.main.url(forResource: "torch", withExtension: "usdz") else {
            fatalError("❌ 找不到 torch.usdz")
        }

        do {
            self.torchModel = try AnimationModelCache.entity(for: url)
        } catch {
            fatalError("❌ 無法載入 torch.usdz：\(error)")
        }

        super.init(type: .torch, scale: scale, isRepeat: isRepeat)
    }

    /// 加入 Anchor 並播放動畫（固定放在鏡頭前方）
    override func applyAnimation(to anchor: AnchorEntity, on arView: ARView) {
        var content = torchModel.clone(recursive: true)
        removeSupportNodes(from: content)
        content = flattenRenderableContent(content)
        sanitizeAnchoring(for: content)

        let wrapper = Entity()
        wrapper.name = "TorchAnimationWrapper"
        wrapper.addChild(content)
        sanitizeAnchoring(for: wrapper)
        applyScale(to: wrapper)
        if let name = ingredient, !name.isEmpty {
            _ = ARText.addLabel(
                text: name,
                to: wrapper,
                padding: 0.05,
                scaleMultiplier: max(scale * 6.0, 1.0)
            )
        }
        anchor.position = SIMD3<Float>(0, -0.5, -distance)
        anchor.addChild(wrapper)

        // 以相機為基準的錨點，確保距離可控；重用同一個 camera anchor，避免多重父層造成位置看似不變
        let cameraAnchor: AnchorEntity
        if let existing = arView.scene.findEntity(named: "TorchCameraAnchor") as? AnchorEntity {
            cameraAnchor = existing
        } else {
            let ca = AnchorEntity(.camera)
            ca.name = "TorchCameraAnchor"
            arView.scene.addAnchor(ca)
            cameraAnchor = ca
        }
        anchor.setParent(cameraAnchor, preservingWorldTransform: false)
        anchor.transform = Transform(
            scale: .one,
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            translation: SIMD3<Float>(0, -0.5, -distance)
        )

        // 播放動畫
        if let clip = content.availableAnimations.first {
            let resource = isRepeat ? clip.repeat(duration: .infinity) : clip
            content.playAnimation(resource, transitionDuration: 0.1, startsPaused: false)
        } else {
            print("⚠️ [TorchAnimation] USDZ 無可用動畫：torch")
        }
    }

    override func updateBoundingBox(rect: CGRect) {
        // no-op
    }

    private func applyScale(to wrapper: Entity) {
        let finalScalar = max(scale * scaleMultiplier, 0.01)
        wrapper.transform.scale = SIMD3<Float>(repeating: finalScalar)
    }

    private func sanitizeAnchoring(for entity: Entity) {
        entity.components.remove(AnchoringComponent.self)
        entity.components.remove(SynchronizationComponent.self)
        entity.components.remove(PhysicsBodyComponent.self)
        entity.components.remove(PhysicsMotionComponent.self)
        entity.components.remove(CollisionComponent.self)
        for child in entity.children {
            sanitizeAnchoring(for: child)
        }
    }

    private func removeSupportNodes(from entity: Entity) {
        for child in Array(entity.children) {
            let lower = child.name.lowercased()
            if lower.hasPrefix("_") || lower.contains("light") || lower.contains("camera") || lower.contains("env") {
                entity.removeChild(child)
            } else {
                removeSupportNodes(from: child)
            }
        }
    }

    private func flattenRenderableContent(_ entity: Entity) -> Entity {
        var current = entity
        while current.children.count == 1,
              let child = current.children.first,
              shouldFlattenNode(parentName: current.name, childName: child.name) {
            let matrix = child.transformMatrix(relativeTo: current)
            child.transform = Transform(matrix: matrix)
            current.removeChild(child)
            current = child
        }
        return current
    }

    private func shouldFlattenNode(parentName: String, childName: String) -> Bool {
        let parent = parentName.lowercased()
        let child = childName.lowercased()
        if parent.isEmpty || parent == "root" || parent == "world" || parent.hasPrefix("world") {
            return true
        }
        if child == "world" || child.hasPrefix("world") {
            return true
        }
        return false
    }
}
