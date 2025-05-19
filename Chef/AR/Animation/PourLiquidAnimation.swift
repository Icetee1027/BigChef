import Foundation
import simd
import RealityKit
import UIKit
import Vision
import ARKit

class PourLiquidAnimation: Animation {
    private let pourLiquid: Entity
    private let color: UIColor
    private let container: Container
    private var pourLiquidPosition: SIMD3<Float>?
    private var containerBBox: CGRect?
    private var containerPosition: SIMD3<Float>?


    init(container: Container,
         scale: Float = 1.0,
         isRepeat: Bool = false,
         color: UIColor = .white) {
        self.container = container
        self.color = color
        guard let url = Bundle.main.url(forResource: "pourLiquid", withExtension: "usdz") else {
            fatalError("❌ 找不到 pourLiquid.usdz")
        }
        do {
            pourLiquid = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 pourLiquid.usdz：\(error)")
        }
        super.init(type: .pourLiquid, scale: scale, isRepeat: isRepeat)
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
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
                let mid = CGPoint(x: bbox.midX * viewSize.width,
                                  y: (1 - bbox.midY) * viewSize.height)
                let results = arView.raycast(from: mid,
                                             allowing: .estimatedPlane,
                                             alignment: .any)
                completion(results.first?.worldTransform.translation)
            } else {
                let centerPoint = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
                let results = arView.raycast(from: centerPoint,
                                             allowing: .estimatedPlane,
                                             alignment: .any)
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
                    self.runPourLiquid(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runPourLiquid(on arView: ARView, at pos: SIMD3<Float>) {
        // Store container position
        self.containerPosition = pos
        // Create anchor at container position
        let anchor = AnchorEntity(world: pos)
        // Compute box size in world space from containerBBox
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let targetMaxSide = max(Float(bbox.width), Float(bbox.height))
        // Compute model extents to scale liquid entity
        let bounds = self.pourLiquid.visualBounds(recursive: true, relativeTo: anchor)
        let extents = bounds.extents
        let maxModelSide = max(extents.x, extents.y, extents.z)
        let scaleFactor = targetMaxSide / maxModelSide
        let finalScale = min(self.scale, scaleFactor)
        self.pourLiquid.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
        // Position liquid entity above container
        self.pourLiquid.position = SIMD3<Float>(0, 0.1, 0)
        anchor.addChild(self.pourLiquid)
        arView.scene.addAnchor(anchor)
        // Apply material color
        if var model = self.pourLiquid as? ModelEntity {
            model.model?.materials = [SimpleMaterial(color: self.color, isMetallic: false)]
        }
        // Play animation
        if let animation = self.pourLiquid.availableAnimations.first {
            let resource = isRepeat
                ? animation.repeat(duration: .infinity)
                : animation
            _ = self.pourLiquid.playAnimation(resource)
        } else {
            print("⚠️ USDZ 檔案無可用動畫：pourLiquid")
        }
    }
}
