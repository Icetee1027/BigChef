import Foundation
import simd
import RealityKit
import ARKit

/// 炙皮（Peel）動畫：與 Torch 相同風格，固定放在鏡頭前方
class PeelAnimation: Animation {
    // 不需要容器偵測
    override var requiresContainerDetection: Bool { false }
    override var containerType: Container? { nil }

    private let peelModel: Entity
    private let ingredient: String?
    private let distance: Float
    private let scaleMultiplier: Float = 0.4

    init(ingredient: String? = nil,
         scale: Float,
         isRepeat: Bool = true,
         distance: Float = 0.5) {
        self.ingredient = ingredient?.lowercased()
        self.distance = distance

        // 載入 peel.usdz
        guard let url = Bundle.main.url(forResource: "peel", withExtension: "usdz") else {
            fatalError("❌ 找不到 peel.usdz")
        }
        do {
            self.peelModel = try AnimationModelCache.entity(for: url)
        } catch {
            fatalError("❌ 無法載入 peel.usdz：\(error)")
        }

        super.init(type: .peel, scale: scale, isRepeat: isRepeat)
    }

    /// 加入 Anchor 並播放動畫（固定放在鏡頭前方，與 Torch 相同流程）
    override func applyAnimation(to anchor: AnchorEntity, on arView: ARView) {
        var content = peelModel.clone(recursive: true)
        removeSupportNodes(from: content)
        content = flattenRenderableContent(content)
        sanitizeAnchoring(for: content)

        let wrapper = Entity()
        wrapper.name = "PeelAnimationWrapper"
        wrapper.addChild(content)
        sanitizeAnchoring(for: wrapper)
        anchor.addChild(wrapper)
        applyScale(to: wrapper)

        if let ingredient = ingredient {
            _ = ARText.addLabel(
                text: ingredient,
                to: wrapper,
                padding: 0.04,
                scaleMultiplier: max(scale * 8.0, 1.0)
            )
        }

        // 以相機為基準的錨點；重用同一個 camera anchor
        let cameraAnchor: AnchorEntity
        if let existing = arView.scene.findEntity(named: "PeelCameraAnchor") as? AnchorEntity {
            cameraAnchor = existing
        } else {
            let ca = AnchorEntity(.camera)
            ca.name = "PeelCameraAnchor"
            arView.scene.addAnchor(ca)
            cameraAnchor = ca
        }

        // 把外部傳入的 anchor 掛到 camera anchor 底下，並設定距離
        anchor.setParent(cameraAnchor, preservingWorldTransform: false)
        anchor.transform = Transform(
            scale: .one,
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            translation: SIMD3<Float>(0, 0, -distance)
        )

        // 播放 USDZ 內建動畫（若存在）
        if let clip = content.availableAnimations.first {
            let resource = isRepeat ? clip.repeat(duration: .infinity) : clip
            content.playAnimation(resource, transitionDuration: 0.1, startsPaused: false)
        } else {
            print("⚠️ USDZ 無可用動畫：peel")
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
