import Foundation
import simd
import RealityKit
import UIKit
import Vision
import ARKit

class CountdownAnimation: Animation {
    private let countdown: Entity
    private var minutes: Int
    private let container: Container
    private var countdownPosition: SIMD3<Float>?
    private var containerPosition: SIMD3<Float>?
    private var textEntity: ModelEntity?
    private var remainingSeconds: Int = 0
    private var timer: Timer?
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
                let mid = CGPoint(x: match.boundingBox.midX, y: match.boundingBox.midY)
                let screenPoint = CGPoint(x: mid.x * viewSize.width, y: (1-mid.y) * viewSize.height)
                let results = arView.raycast(from: screenPoint,
                                             allowing: .estimatedPlane,
                                             alignment: .any)
                let worldPos = results.first?.worldTransform.translation
                completion(worldPos)
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
                    self.runCountdown(on: arView, at: positionToUse)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.attemptContinuousDetection(in: arView)
                }
            }
        }
    }

    private func runCountdown(on arView: ARView, at pos: SIMD3<Float>) {
        let anchor = AnchorEntity(world: pos)
        let entity = countdown
        anchor.addChild(entity)
        self.remainingSeconds = self.minutes * 60
        let bbox = self.containerBBox ?? CGRect(x: 0, y: 0, width: 1, height: 0.5)
        let containerFrame = CGRect(origin: .zero, size: CGSize(width: bbox.width, height: bbox.height))
        let textMesh = MeshResource.generateText(
            self.formatTime(self.remainingSeconds),
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.2),
            containerFrame: containerFrame,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let textMaterial = UnlitMaterial(color: .white)
        self.textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        self.textEntity!.setPosition(SIMD3<Float>(0, 0.3, 0), relativeTo: entity)
        entity.addChild(self.textEntity!)
        arView.scene.addAnchor(anchor)
        // Start timer
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.remainingSeconds -= 1
                if self.remainingSeconds < 0 {
                    self.timer?.invalidate()
                } else {
                    // update text
                    let newText = self.formatTime(self.remainingSeconds)
                    let newMesh = MeshResource.generateText(
                        newText,
                        extrusionDepth: 0.01,
                        font: .systemFont(ofSize: 0.2),
                        containerFrame: containerFrame,
                        alignment: .center,
                        lineBreakMode: .byWordWrapping
                    )
                    self.textEntity?.model?.mesh = newMesh
                }
            }
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    override func play(on arView: ARView) {
        attemptContinuousDetection(in: arView)
    }

    init(minutes: Int = 1,
         container: Container,
         scale: Float = 1.0,
         isRepeat: Bool = false) {
        self.container = container
        guard let url = Bundle.main.url(forResource: "countdown", withExtension: "usdz") else {
            fatalError("❌ 找不到 countdown.usdz")
        }
        do {
            countdown = try Entity.load(contentsOf: url)
        } catch {
            fatalError("❌ 無法載入 countdown.usdz：\(error)")
        }
        self.minutes = minutes
        super.init(type: .countdown, scale: scale, isRepeat: isRepeat)
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
