import Foundation
import simd
import RealityKit
import Vision
import ARKit

class StirAnimation: Animation {
    private let stir: Entity
    private let container: Container
    private var containerPosition: SIMD3<Float>?
    private var stirPosition: SIMD3<Float>?
    private var containerBBox: CGRect?

    init(container: Container, scale: Float = 1.0, isRepeat: Bool = false) {
        self.container = container
        guard let url = Bundle.main.url(forResource: "stir", withExtension: "usdz") else {
            fatalError("❌ 找不到 stir.usdz")
        }
        do {
            stir = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 stir.usdz：\(error)")
        }
        super.init(type: .stir, scale: scale, isRepeat: isRepeat)
    }

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
                let screenPoint = CGPoint(x: mid.x * viewSize.width, y: (1 - mid.y) * viewSize.height)
                let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
                completion(results.first?.worldTransform.translation)
            } else {
                let centerPoint = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
                let results = arView.raycast(from: centerPoint, allowing: .estimatedPlane, alignment: .any)
                completion(results.first?.worldTransform.translation)
            }
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func attemptContinuousDetection(in arView: ARView) {
        detectContainerPosition(in: arView) { pos in
            if let positionToUse = pos {
                DispatchQueue.main.async {
                    self.runStir(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runStir(on arView: ARView, at pos: SIMD3<Float>) {
        let anchor = AnchorEntity(world: pos)
        let entity = stir
        // compute scale based on bounding box
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let normalizedMaxSide = max(Float(bbox.width), Float(bbox.height))
        let stirBounds = entity.visualBounds(recursive: true, relativeTo: anchor)
        let modelExtents = stirBounds.extents
        let maxModelSide = max(modelExtents.x, modelExtents.y, modelExtents.z)
        let scaleFactor = normalizedMaxSide / maxModelSide
        let finalScale = min(self.scale, scaleFactor)
        entity.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
        // position stir slightly above container
        entity.position = SIMD3<Float>(0, normalizedMaxSide/2 + 0.05, 0)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        // play animation
        if let animation = entity.availableAnimations.first {
            let resource = isRepeat ? animation.repeat(duration: .infinity) : animation
            _ = entity.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：stir")
        }
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }
}
