import UIKit
import Vision
import ARKit
import Foundation
import simd
import RealityKit

class BeatEggAnimation: Animation {
    private let beatEgg: Entity
    private let container: Container
    private var containerBBox: CGRect?
    private var beatEggPosition: SIMD3<Float>?
    private var containerPosition: SIMD3<Float>?
    
    init(container: Container,scale: Float = 1.0, isRepeat: Bool = false) {
        self.container = container
        guard let url = Bundle.main.url(forResource: "beatEgg", withExtension: "usdz") else {
            fatalError("❌ 找不到 beatEgg.usdz")
        }
        do {
            beatEgg = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 beatEgg.usdz：\(error)")
        }
        super.init(type: .beatEgg, scale: scale, isRepeat: isRepeat)
    }
    
    private func detectContainerPosition(in arView: ARView, completion: @escaping (SIMD3<Float>?) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completion(nil); return
        }
        let pixelBuffer = frame.capturedImage
        guard let visionModel = try? VNCoreMLModel(for: CookDetect().model) else {
            completion(nil); return
        }
        let request = VNCoreMLRequest(model: visionModel) { req, _ in
            guard let observations = req.results as? [VNRecognizedObjectObservation] else {
                completion(nil); return
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
                let center = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
                let results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .any)
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
            if let position = pos {
                DispatchQueue.main.async {
                    self.runBeatEgg(on: arView, at: position)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }
    
    private func runBeatEgg(on arView: ARView, at position: SIMD3<Float>) {
        let anchor = AnchorEntity(world: position)
        let dropHeight: Float = 0.3
        anchor.addChild(beatEgg)
        self.beatEgg.position = SIMD3<Float>(0, dropHeight, 0)
        // Scale to fit bounding box
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let normalizedMaxSide = max(Float(bbox.width), Float(bbox.height))
        let bounds = beatEgg.visualBounds(recursive: true, relativeTo: anchor).extents
        let maxModelSide = max(bounds.x, bounds.y, bounds.z)
        let scaleFactor = normalizedMaxSide / maxModelSide
        let finalScale = min(self.scale, scaleFactor)
        beatEgg.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
        arView.scene.addAnchor(anchor)
    }
    
    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }
}
