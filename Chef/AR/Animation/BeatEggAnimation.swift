import UIKit
import Foundation
import simd
import RealityKit

class BeatEggAnimation: Animation {
    private let beatEggTemplate: Entity
    private let container: Container
    private var containerBBox: CGRect?
    private var beatEggInstance: Entity?
    private weak var arViewRef: ARView?
    private var detectionObserver: NSObjectProtocol?
    private var containerCenter: SIMD3<Float>?

    init(container: Container, scale: Float = 1.0, isRepeat: Bool = false) {
        self.container = container
        guard let url = Bundle.main.url(forResource: "beatEgg", withExtension: "usdz") else {
            fatalError("❌ 找不到 beatEgg.usdz")
        }
        do {
            beatEggTemplate = try AnimationModelCache.entity(for: url)
        } catch {
            fatalError("❌ 無法載入 beatEgg.usdz：\(error)")
        }
        super.init(type: .beatEgg, scale: scale, isRepeat: isRepeat)
    }

    override var requiresContainerDetection: Bool { true }
    override var containerType: Container? { container }

    private func normalizedBoundingBox() -> CGRect? {
        guard let bbox = containerBBox else { return nil }

        // 原始 Vision 偵測會回傳 0...1 的 normalized 值；若已經是這種格式直接使用。
        if bbox.width <= 1.0 && bbox.height <= 1.0 {
            return bbox
        }

        guard let arView = arViewRef else { return bbox }
        let viewSize = arView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return bbox }

        return CGRect(
            x: bbox.origin.x / viewSize.width,
            y: bbox.origin.y / viewSize.height,
            width: bbox.width / viewSize.width,
            height: bbox.height / viewSize.height
        )
    }

    private func startObservingDetections() {
        guard detectionObserver == nil else { return }
        detectionObserver = NotificationCenter.default.addObserver(
            forName: .objectDetectorDidDetectContainer,
            object: ObjectDetector.shared,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let identifier = notification.userInfo?[ObjectDetector.NotificationKeys.identifier] as? String,
                  identifier == self.container.rawValue,
                  let rectValue = notification.userInfo?[ObjectDetector.NotificationKeys.normalizedRect] as? NSValue
            else { return }

            let normalizedRect = rectValue.cgRectValue
            self.updateBoundingBox(rect: normalizedRect)
        }
    }

    private func stopObservingDetections() {
        if let observer = detectionObserver {
            NotificationCenter.default.removeObserver(observer)
            detectionObserver = nil
        }
    }

    private func applyScaleAndOffset(to entity: Entity, relativeTo anchor: AnchorEntity) {
        let dropHeight: Float = 0.3
        let forwardOffset: Float = -0.28
        entity.position = SIMD3<Float>(0, dropHeight - 0.4, forwardOffset)

        let bbox = normalizedBoundingBox() ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let normalizedMaxSide = max(Float(bbox.width), Float(bbox.height))
        let bounds = entity.visualBounds(recursive: true, relativeTo: anchor).extents
        let maxModelSide = max(bounds.x, bounds.y, bounds.z)

        let scaleReduction: Float = 0.75

        guard normalizedMaxSide > 0, maxModelSide > 0 else {
            entity.setScale(SIMD3<Float>(repeating: scale * scaleReduction), relativeTo: anchor)
            return
        }

        let scaleFactor = normalizedMaxSide / maxModelSide
        let finalScale = min(scale, scaleFactor) * scaleReduction
        entity.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
    }

    override func applyAnimation(to anchor: AnchorEntity, on arView: ARView) {
        arViewRef = arView
        startObservingDetections()

        if let latest = ObjectDetector.shared.latestDetection,
           latest.identifier == container.rawValue {
            updateBoundingBox(rect: latest.normalizedRect)
        }

        let beatEgg = beatEggTemplate.clone(recursive: true)
        anchor.addChild(beatEgg)
        beatEggInstance = beatEgg
        applyScaleAndOffset(to: beatEgg, relativeTo: anchor)

        let clips = beatEgg.availableAnimations
        if let first = clips.first {
            let playable = isRepeat ? first.repeat(duration: .infinity) : first
            beatEgg.playAnimation(playable, transitionDuration: 0.2, startsPaused: false)
        } else {
            let target = Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: [0,1,0]), translation: .zero)
            beatEgg.move(to: target, relativeTo: anchor, duration: 0.35, timingFunction: .easeInOut)
        }
    }

    override func updatePosition(_ position: SIMD3<Float>) {
        containerCenter = position
        super.updatePosition(position)
        guard let anchor = anchorEntity, let beatEgg = beatEggInstance else { return }
        applyScaleAndOffset(to: beatEgg, relativeTo: anchor)
    }

    override func updateBoundingBox(rect: CGRect) {
        containerBBox = rect
        guard let anchor = anchorEntity, let beatEgg = beatEggInstance else { return }
        applyScaleAndOffset(to: beatEgg, relativeTo: anchor)
    }

    override func stop() {
        super.stop()
        beatEggInstance = nil
        arViewRef = nil
        stopObservingDetections()
        containerBBox = nil
        containerCenter = nil
    }
}
