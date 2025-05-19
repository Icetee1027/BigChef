import Vision
import Foundation
import simd
import RealityKit
import ARKit
import UIKit

class PutIntoContainerAnimation: Animation {
    private let ingredientName: String
    private let ingredient: Entity
    private let container: Container
    private var ingredientPosition: SIMD3<Float>?
    private var containerPosition: SIMD3<Float>?
    private var anchorEntity: AnchorEntity?
    private var screenCenter: CGPoint?
    
    private var dropDuration: TimeInterval = 0.7

    init(ingredientName: String, container: Container, scale: Float = 1.0, isRepeat: Bool = true) {
        self.ingredientName = ingredientName
        self.container = container
        guard let url = Bundle.main.url(forResource: ingredientName, withExtension: "usdz") else {
            fatalError("❌ 找不到 \(ingredientName).usdz")
        }
        do {
            ingredient = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 \(ingredientName).usdz：\(error)")
        }
        super.init(type: .putIntoContainer, scale: scale, isRepeat: isRepeat)
    }

    private func detectContainerPosition(in arView: ARView, completion: @escaping (SIMD3<Float>?) -> Void) {
        print("🔍 detectContainerPosition called")
        guard let frame = arView.session.currentFrame else {
            completion(nil)
            return
        }
        let pixelBuffer = frame.capturedImage
        guard let visionModel = try? VNCoreMLModel(for: CookDetect().model) else {
            completion(nil)
            print("CookDetect model error")
            return
        }
        let request = VNCoreMLRequest(model: visionModel) { req, _ in
            print("🔍 VNCoreMLRequest callback invoked")
            guard let observations = req.results as? [VNRecognizedObjectObservation] else {
                completion(nil)
                return
            }
            let viewSize = arView.bounds.size
            guard let match = observations.first(where: { obs in
                obs.labels.contains { $0.identifier.lowercased().contains(self.container.rawValue.lowercased()) }
            }) else {
                let centerPoint = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                let allowTargets: ARRaycastQuery.Target = .estimatedPlane
                let fallbackResults = arView.raycast(from: centerPoint,
                                                     allowing: allowTargets,
                                                     alignment: .any)
                let fallbackPos = fallbackResults.first?.worldTransform.translation
                DispatchQueue.main.async {
                    arView.viewWithTag(1001)?.removeFromSuperview()
                }
                print("🔍 detectContainerPosition fallback to estimatedPlane:", fallbackPos as Any)
                completion(fallbackPos)
                return
            }
            let bbox = match.boundingBox
            print("🔍 BoundingBox values - minX: \(bbox.minX), minY: \(bbox.minY), width: \(bbox.width), height: \(bbox.height)")
            let rect = CGRect(
                x: bbox.minX * viewSize.width,
                y: (1 - bbox.maxY) * viewSize.height,
                width: bbox.width * viewSize.width,
                height: bbox.height * viewSize.height
            )
            DispatchQueue.main.async {
                if let boxView = arView.viewWithTag(1001) {
                    boxView.frame = rect
                } else {
                    let boxView = UIView(frame: rect)
                    boxView.layer.borderColor = UIColor.red.cgColor
                    boxView.layer.borderWidth = 2
                    boxView.tag = 1001
                    arView.addSubview(boxView)
                }
            }
            let normalizedCenter = CGPoint(x: bbox.midX, y: bbox.midY)
            self.screenCenter = normalizedCenter
            let screenPoint = CGPoint(
                x: normalizedCenter.x * viewSize.width,
                y: (1 - normalizedCenter.y) * viewSize.height
            )
            print("🔍 Raycasting from screen point:", screenPoint)
            let allowTargets: ARRaycastQuery.Target = .estimatedPlane
            let results = arView.raycast(from: screenPoint,
                                         allowing: allowTargets,
                                         alignment: .any)
            self.containerPosition = results.first?.worldTransform.translation
            print("🔍 detectContainerPosition found match position:", self.containerPosition as Any)
            completion(results.first?.worldTransform.translation)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func attemptContinuousDetection(in arView: ARView) {
        detectContainerPosition(in: arView) { detectedPos in
            print("🔍 continuous detect callback with detectedPos:", detectedPos as Any)
            if let positionToUse = detectedPos {
                self.runPutIntoContainer(on: arView, at: positionToUse)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runPutIntoContainer(on arView: ARView, at positionToUse: SIMD3<Float>) {
        self.ingredientPosition = positionToUse
        let cameraAnchor = AnchorEntity(.camera)
        self.anchorEntity = cameraAnchor
        arView.scene.addAnchor(cameraAnchor)
        let center = self.screenCenter ?? CGPoint(x: 0.5, y: 0.5)
        let xOffset = Float(center.x - 0.5)
        let yOffset = Float(0.5 - center.y)
        let dropStartHeight: Float = 0.2
        self.ingredient.position = SIMD3<Float>(xOffset, yOffset + dropStartHeight, -0.5)
        
        DispatchQueue.main.async {
            let boxSize: Float = 0.2
            let boxMesh = MeshResource.generateBox(size: boxSize)
            let boxMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [boxMaterial])
            let ingredientBounds = self.ingredient.visualBounds(recursive: true, relativeTo: cameraAnchor)
            let modelExtents = ingredientBounds.extents
            let maxModelSide = max(modelExtents.x, modelExtents.y, modelExtents.z)
            let targetMax = boxSize
            let scaleFactor = targetMax / maxModelSide
            let finalScale = min(self.scale, scaleFactor)
            self.ingredient.setScale(SIMD3<Float>(repeating: finalScale), relativeTo: cameraAnchor)
            cameraAnchor.addChild(self.ingredient)
            
            let dropTransform = Transform(translation: SIMD3<Float>(xOffset, yOffset, -0.5))
            self.ingredient.move(to: dropTransform,
                                 relativeTo: cameraAnchor,
                                 duration: 0.7,
                                 timingFunction: .easeIn)
            self.trackContainerMovement(in: arView)
            self.dropDuration = 0.7
            self.startContinuousDrop()
        }
    }

    private func trackContainerMovement(in arView: ARView) {
        print("🔍 trackContainerMovement scheduling detection")
        detectContainerPosition(in: arView) { [weak self] newPos in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let pos = newPos, let anchor = self.anchorEntity {
                    anchor.move(to: Transform(translation: pos), relativeTo: nil, duration: 0.1, timingFunction: .linear)
                    let dropStartHeight: Float = 0.5
                    self.ingredient.position = SIMD3<Float>(0, dropStartHeight, 0)
                    let dropTransform = Transform(translation: SIMD3<Float>(0, 0, 0))
                    self.ingredient.move(to: dropTransform,
                                         relativeTo: anchor,
                                         duration: 0.7,
                                         timingFunction: .easeIn)
                } else {
                    print("🔍 trackContainerMovement: no position detected")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.trackContainerMovement(in: arView)
            }
        }
    }

    private func startContinuousDrop() {
        guard let anchor = anchorEntity else { return }
        let dropStartHeight: Float = 0.5
        DispatchQueue.main.async {
            self.ingredient.position = SIMD3<Float>(0, dropStartHeight, 0)
            // Animate drop with current duration
            self.ingredient.move(to: Transform(translation: SIMD3<Float>(0, 0, 0)),
                                 relativeTo: anchor,
                                 duration: self.dropDuration,
                                 timingFunction: .easeIn)
        }
        self.dropDuration *= 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + self.dropDuration + 0.1) {
            self.startContinuousDrop()
        }
    }

    override func play(on arView: ARView) {
        print("🔍 play(on:) called for ingredient:", ingredientName, "container:", container.rawValue)
        attemptContinuousDetection(in: arView)
    }
}

enum Container: String, CaseIterable, Codable {
    case airFryer
    case bowl
    case microWaveOven
    case oven
    case pan
    case plate
    case riceCooker
    case soupPot
}

