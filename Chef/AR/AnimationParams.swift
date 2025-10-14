import Foundation

/// Shared container for AR animation parameters coming from the backend.
struct AnimationParams: Codable {
    let coordinate: [Float]?
    let container: Container?
    let ingredient: String?
    let color: String?
    let time: Float?
    let temperature: Float?
    let flameLevel: String?
}
