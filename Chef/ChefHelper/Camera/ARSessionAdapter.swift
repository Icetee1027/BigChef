//
//  ARSessionAdapter.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/5/7.
//


import UIKit
import ARKit

/// ARKit 的包裝，符合 CameraSession
final class ARSessionAdapter: NSObject, CameraSession {

    private let sceneView = ARSCNView(frame: .zero)
    let previewView: UIView

    override init() {
        previewView = sceneView
        super.init()
        sceneView.automaticallyUpdatesLighting = true
    }

    // MARK: - CameraSession
    func start() {
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        sceneView.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() { sceneView.session.pause() }
}
