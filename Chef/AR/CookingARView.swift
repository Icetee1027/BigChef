import SwiftUI
import RealityKit
import ARKit
import Combine
import Foundation
import UIKit
import simd

struct CookingARView: UIViewRepresentable {

    @ObservedObject var viewModel: StepViewModel
    private let manager = AnimationManger()

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        return arView
    }

    @MainActor
    func updateUIView(_ uiView: ARView, context: Context) {
        let step = viewModel.currentDescription
        guard !step.isEmpty, context.coordinator.lastStep != step else { return }
        context.coordinator.lastStep = step
        uiView.scene.anchors.removeAll()

        Task { @MainActor in

            guard let (type, params) = await manager.selectTypeAndParameters(for: step, from: uiView) else { return }
            var animation: Animation = Animation(type: type, scale: 1.0, isRepeat: false)
            
            switch type {

            case .putIntoContainer:
                let containerEnum = params.container ?? .pan
                animation = PutIntoContainerAnimation(
                    ingredientName: params.ingredient ?? "",
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: true
                )
            case .stir:
                let containerEnum = params.container ?? .pan
                animation = StirAnimation(
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: true
                )
            case .pourLiquid:
                let liquidColor = UIColor(named: params.color ?? "") ?? .white
                let containerEnum = params.container ?? .pan
                animation = PourLiquidAnimation(
                    container: containerEnum,
                        scale: 1.0,
                        isRepeat: false,
                        color: liquidColor
                    )
            case .flipPan, .flip:
                let containerEnum = params.container ?? .pan
                animation = FlipAnimation(
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: false
                )
            case .countdown:
                let containerEnum = params.container ?? .pan
                animation = CountdownAnimation(
                    minutes: Int(params.time ?? 1),
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: false
                )
            case .temperature:
                    let containerEnum = params.container ?? .pan
                    animation = TemperatureAnimation(
                        container: containerEnum,
                        temperatureValue: Int(params.temperature ?? 0),
                        scale: 1.0,
                        isRepeat: false
                    )
            case .flame:
                let flameLevel = FlameLevel(rawValue: params.FlameLevel ?? FlameLevel.medium.rawValue) ?? .medium
                let containerEnum = params.container ?? .pan
                animation = FlameAnimation(
                    level: flameLevel,
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: false
                )
            case .sprinkle:
                let sprinkleColor = UIColor(named: params.color ?? "") ?? .white // if needed for color
                let containerEnum = params.container ?? .pan
                animation = SprinkleAnimation(
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: false
                )
            case .torch:
                if let coords = params.coordinate, coords.count == 3 {
                    let position = SIMD3<Float>(coords[0], coords[1], coords[2])
                    let containerEnum = params.container ?? .pan
                    animation = TorchAnimation(
                        torchPosition: position,
                        scale: 1.0,
                        isRepeat: false
                    )
                } else {
                    print("⚠️ 未設定有效的座標，無法播放 torch 動畫")
                    break
                }
            case .cut:
                if let coords = params.coordinate, coords.count == 3 {
                    let position = SIMD3<Float>(coords[0], coords[1], coords[2])
                    animation = CutAnimation(cutPosition: position, scale: 1.0, isRepeat: false)
                } else {
                    print("⚠️ 未設定有效的座標，無法播放 cut 動畫")
                    break
                }
            case .peel:
                if let coords = params.coordinate, coords.count == 3 {
                    let position = SIMD3<Float>(coords[0], coords[1], coords[2])
                    animation = PeelAnimation(
                        peelPosition: position,
                        scale: 1.0,
                        isRepeat: false
                    )
                } else {
                    print("⚠️ 未設定有效的座標，無法播放 peel 動畫")
                    break
                }
            case .beatEgg:
                let containerEnum = params.container ?? .bowl
                animation  = BeatEggAnimation(
                    container: containerEnum,
                    scale: 1.0,
                    isRepeat: true
                )
            }

            animation.play(on: uiView)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                uiView.scene.anchors.removeAll()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    class Coordinator {
        var lastStep: String = ""
        var lastType: AnimationType?
    }
}
