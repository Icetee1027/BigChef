import Foundation
import simd
import RealityKit
import UIKit
import Vision
import ARKit

class TemperatureAnimation: Animation {
    private let temperatureValue: Int
    private let temperature: Entity
    private let container: Container
    private var temperaturePosition: SIMD3<Float>?
    private var containerPosition: SIMD3<Float>?

    private var containerBBox: CGRect?


    init(container: Container, temperatureValue: Int, scale: Float = 1.0, isRepeat: Bool = false) {
        self.container = container
        self.temperatureValue = temperatureValue
        guard let url = Bundle.main.url(forResource: "temperature", withExtension: "usdz") else {
            fatalError("❌ 找不到 temperature.usdz")
        }
        do {
            temperature = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 temperature.usdz：\(error)")
        }
        super.init(type: .temperature, scale: scale, isRepeat: isRepeat)
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
                let results = arView.raycast(from: screenPoint,
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
                    self.runTemperature(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runTemperature(on arView: ARView, at pos: SIMD3<Float>) {
        // Anchor at detected container position
        let anchor = AnchorEntity(world: pos)
        arView.scene.addAnchor(anchor)
        // Scale temperature entity to not exceed container bounding box
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 0.2, height: 0.2)
        let maxNormalizedSide = max(Float(bbox.width), Float(bbox.height))
        let bounds = self.temperature.visualBounds(recursive: true, relativeTo: anchor)
        let modelExtents = bounds.extents
        let maxModelSide = max(modelExtents.x, modelExtents.y, modelExtents.z)
        let scaleFactor = maxNormalizedSide / maxModelSide
        let finalScale = min(self.scale, scaleFactor)
        self.temperature.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: anchor)
        anchor.addChild(self.temperature)
        // Display temperatureValue as text above the entity
        let text = "\(self.temperatureValue)°"
        let containerFrame = CGRect(origin: .zero, size: CGSize(width: bbox.width, height: bbox.height))
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.2),
            containerFrame: containerFrame,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let textMaterial = UnlitMaterial(color: .white)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Position text above the temperature entity
        let yOffset = modelExtents.y * finalScale + 0.05
        textEntity.setPosition(SIMD3<Float>(0, yOffset, 0), relativeTo: anchor)
        anchor.addChild(textEntity)
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }
}
