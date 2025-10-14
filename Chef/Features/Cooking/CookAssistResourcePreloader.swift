import Foundation
@preconcurrency import SceneKit

final class CookAssistResourcePreloader: @unchecked Sendable {
    static let shared = CookAssistResourcePreloader()
    static let defaultWakeWord = "阿里"

    private let stateQueue = DispatchQueue(label: "com.bigchef.cooking.preloader", attributes: .concurrent)

    private var voiceServices: [String: QAKeywordVoiceService] = [:]
    private var voicePermissionRequested = false
    private var voicePermissionGranted = false
    private var gestureManager: HandDetectionManager?
    private var qaScenes: [String: SCNScene] = [:]

    private init() {}

    func voiceService(wakeWord: String) -> QAKeywordVoiceService {
        if let existing = stateQueue.sync(execute: { voiceServices[wakeWord] }) {
            return existing
        }

        return stateQueue.sync(flags: .barrier) {
            let service = QAKeywordVoiceService(wakeWord: wakeWord)
            voiceServices[wakeWord] = service
            return service
        }
    }

    func preloadVoiceControl(wakeWord: String) async {
        let service = voiceService(wakeWord: wakeWord)
        let shouldRequest = stateQueue.sync { !voicePermissionRequested }
        guard shouldRequest else { return }

        stateQueue.sync(flags: .barrier) {
            voicePermissionRequested = true
        }

        let granted = await requestPermissionsIfNeeded(for: service)

        stateQueue.sync(flags: .barrier) {
            voicePermissionGranted = granted
            if !granted {
                voicePermissionRequested = false
            }
        }
    }

    func preloadGestureControl() async {
        let needsWarmup = stateQueue.sync { gestureManager == nil }
        guard needsWarmup else { return }

        stateQueue.sync(flags: .barrier) {
            let manager = HandDetectionManager()
            manager.setGestureEnabled(false)
            gestureManager = manager
        }
    }

    func preloadQAInteractionResources(named resourceName: String = "firebaby", fileExtension: String = "usdz") async {
        let alreadyLoaded = stateQueue.sync { qaScenes[resourceName] != nil }
        guard !alreadyLoaded else { return }

        let scene = await Task.detached(priority: .userInitiated) { () -> SCNScene? in
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
                return nil
            }
            return try? SCNScene(url: url, options: nil)
        }.value

        guard let scene else { return }

        stateQueue.sync(flags: .barrier) {
            qaScenes[resourceName] = scene
        }
    }

    func qaInteractionScene(named resourceName: String = "firebaby") async -> SCNScene? {
        if let cached = stateQueue.sync(execute: { qaScenes[resourceName] }) {
            return cached
        }
        await preloadQAInteractionResources(named: resourceName)
        return stateQueue.sync { qaScenes[resourceName] }
    }

    var hasVoicePermission: Bool {
        stateQueue.sync { voicePermissionGranted }
    }

    private func requestPermissionsIfNeeded(for service: QAKeywordVoiceService) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                service.requestPermissions { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
