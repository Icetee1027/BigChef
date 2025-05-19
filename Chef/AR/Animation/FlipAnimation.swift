import Foundation
import simd
import RealityKit
import UIKit
import Vision
import ARKit

class FlipAnimation: Animation {
    private var flip: Entity
    private let container: Container
    private var containerBBox: CGRect?
    private var flipPosition: SIMD3<Float>?
    private var containerPosition: SIMD3<Float>?

    init(container: Container,
         scale: Float = 1.0,
         isRepeat: Bool = true) {
        self.container = container
        self.flip = Entity()
        super.init(type: .flip,
                   scale: scale,
                   isRepeat: isRepeat)
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
                    self.runFlip(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runFlip(on arView: ARView, at pos: SIMD3<Float>) {
        // Load or reuse flip entity
        download(resourceName: "flip") { [weak self] node in
            guard let self = self, let node = node else {
                print("⚠️ 載入 flip.usdz 失敗")
                return
            }
            self.flip = node
            // Scale to fit into detected bbox
            let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
            let targetMax = max(Float(bbox.width), Float(bbox.height))
            let bounds = node.visualBounds(recursive: true, relativeTo: nil)
            let extents = bounds.extents
            let maxSide = max(extents.x, extents.y, extents.z)
            let scaleFactor = targetMax / maxSide
            let finalScale = min(self.scale, scaleFactor)
            node.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: nil)
            // Place above container
            let anchor = AnchorEntity(world: pos)
            anchor.addChild(node)
            arView.scene.addAnchor(anchor)
            // Play USDZ animation if available
            if let animation = node.availableAnimations.first {
                let resource = self.isRepeat ? animation.repeat(duration: .infinity) : animation
                _ = node.playAnimation(resource)
            } else {
                print("⚠️ USDZ 檔案無可用動畫：flipEntity")
            }
        }
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }
}
