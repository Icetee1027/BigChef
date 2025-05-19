import Foundation
import simd
import RealityKit
import Vision
import ARKit

enum FlameLevel: String {
    case small
    case medium
    case large
}

class FlameAnimation: Animation {
    private let flame: Entity
    private let flameLevel: FlameLevel
    private let container: Container
    private var containerPosition: SIMD3<Float>?
    private var containerBBox: CGRect?

    private func detectContainerPosition(in arView: ARView, completion: @escaping (SIMD3<Float>?) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completion(nil)
            return
        }
        let pixelBuffer = frame.capturedImage
        guard let visionModel = try? VNCoreMLModel(for: CookDetect().model) else {
            completion(nil)
            return
        }
        let request = VNCoreMLRequest(model: visionModel) { req, _ in
            guard let observations = req.results as? [VNRecognizedObjectObservation] else {
                completion(nil)
                return
            }
            let viewSize = arView.bounds.size
            if let match = observations.first(where: {
                $0.labels.contains { $0.identifier.lowercased().contains(self.container.rawValue.lowercased()) }
            }) {
                let bbox = match.boundingBox
                self.containerBBox = bbox
                let mid = CGPoint(x: bbox.midX, y: bbox.midY)
                let screenPoint = CGPoint(x: mid.x * viewSize.width,
                                          y: (1 - mid.y) * viewSize.height)
                let results = arView.raycast(from: screenPoint,
                                             allowing: .estimatedPlane,
                                             alignment: .any)
                let worldPos = results.first?.worldTransform.translation
                self.containerPosition = worldPos
                completion(worldPos)
            } else {
                let center = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
                let results = arView.raycast(from: center,
                                             allowing: .estimatedPlane,
                                             alignment: .any)
                let worldPos = results.first?.worldTransform.translation
                completion(worldPos)
            }
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func attemptContinuousDetection(in arView: ARView) {
        detectContainerPosition(in: arView) { pos in
            if let positionToUse = pos {
                DispatchQueue.main.async {
                    self.runFlame(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    init(level: FlameLevel = .medium,
         container: Container,
         scale: Float = 1.0,
         isRepeat: Bool = false) {
        let resourceName = "flame_\(level.rawValue)"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz") else {
            fatalError("❌ 找不到 \(resourceName).usdz")
        }
        do {
            flame = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 \(resourceName).usdz：\(error)")
        }
        self.flameLevel = level
        self.container = container
        super.init(type: .flame, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }

    private func runFlame(on arView: ARView, at pos: SIMD3<Float>) {
        let anchor = AnchorEntity(world: pos)
        let entity = flame
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let maxSide = max(Float(bbox.width), Float(bbox.height))
        let bounds = entity.visualBounds(recursive: true, relativeTo: anchor).extents
        let modelMax = max(bounds.x, bounds.y, bounds.z)
        let scaleFactor = maxSide / modelMax
        let finalScale = min(self.scale, scaleFactor)
        entity.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
        let yOffset = -Float(bbox.height) * 0.5
        entity.position = SIMD3<Float>(0, yOffset, 0)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        if let animationPlayback = entity.availableAnimations.first {
            let resource = isRepeat
                ? animationPlayback.repeat(duration: .infinity)
                : animationPlayback
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 無可用動畫：flame")
        }
    }
}
