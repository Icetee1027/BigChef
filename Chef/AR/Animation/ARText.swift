import Foundation
import RealityKit
import UIKit

enum ARText {
    @discardableResult
    static func addLabel(
        text: String,
        to model: Entity,
        padding: Float = 0.02,
        color: UIColor = .white,
        maxWidthRatio: Float = 0.9,
        fontSize: CGFloat = 0.24,
        weight: UIFont.Weight = .semibold,
        boundingOverride: BoundingBox? = nil,
        scaleMultiplier: Float = 1.0
    ) -> ModelEntity {
        let formattedText: String
        if text.contains(",") {
            let segments = text.split(separator: ",", omittingEmptySubsequences: false)
            formattedText = segments
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        } else {
            formattedText = text
        }

        let mesh = MeshResource.generateText(
            formattedText,
            extrusionDepth: 0.005,
            font: .systemFont(ofSize: fontSize, weight: weight),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: color, isMetallic: false)
        let label = ModelEntity(mesh: mesh, materials: [material])

        let baseBounds = boundingOverride ?? model.visualBounds(relativeTo: model)
        let availableWidth = max(baseBounds.extents.x * maxWidthRatio, 0.05)

        let originalBounds = label.visualBounds(relativeTo: label)
        let width = max(originalBounds.extents.x, 0.001)
        let rawRatio = max(availableWidth / width, 0.001 as Float)
        let scaleFactor = min(rawRatio, 1.0 as Float)
        let clampedMultiplier = max(scaleMultiplier, 0.01 as Float)
        let finalScale = min(scaleFactor * clampedMultiplier, rawRatio)
        label.scale = SIMD3<Float>(repeating: finalScale)

        let scaledBounds = label.visualBounds(relativeTo: label)
        let yPos = baseBounds.max.y + padding + scaledBounds.extents.y * 0.5
        let offsetX = -scaledBounds.center.x
        let offsetZ = -scaledBounds.center.z
        label.position = SIMD3<Float>(offsetX, yPos, offsetZ)
        label.components.set(BillboardComponent())

        model.addChild(label)
        return label
    }
}
