//
//  QAKeywordVoiceService.swift
//  ChefHelper
//
//  Created by Codex on 2025/05/07.
//

import Foundation
import AVFoundation
import AVFAudio
import Speech

/// Manages wake word detection and dictation for the cooking QA flow.
final class QAKeywordVoiceService: NSObject, @unchecked Sendable {
    
    enum Mode {
        case idle
        case keywordListening
        case dictating
    }
    
    enum VoiceError: Error {
        case speechRecognizerUnavailable
        case permissionDenied
        case audioEngineError
    }
    
    private let wakeWord: String
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false
    private var isListeningForWakeWord = false
    
    private var mode: Mode = .idle
    private var isSpeechPermissionGranted = false
    private var isRecordPermissionGranted = false
    
    var onKeywordDetected: (() -> Void)?
    var onDictationTextChanged: ((String) -> Void)?
    var onDictationFinished: (() -> Void)?
    var onError: ((Error) -> Void)?
    var keywordTranscriptLogger: ((String) -> Void)?
    
    init(wakeWord: String, locale: Locale = Locale(identifier: "zh-TW")) {
        self.wakeWord = wakeWord
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }
    
    // MARK: - Public API
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        requestSpeechPermission { [weak self] speechGranted in
            guard let self else {
                completion(false)
                return
            }
            self.isSpeechPermissionGranted = speechGranted
            guard speechGranted else {
                completion(false)
                return
            }
            
            self.requestRecordPermission { [weak self] recordGranted in
                self?.isRecordPermissionGranted = recordGranted
                completion(recordGranted)
            }
        }
    }
    
    func startKeywordListening(logStart: Bool = true) {
        guard speechRecognizer?.isAvailable == true else {
            onError?(VoiceError.speechRecognizerUnavailable)
            return
        }
        guard isSpeechPermissionGranted, isRecordPermissionGranted else {
            onError?(VoiceError.permissionDenied)
            return
        }
        guard !isListeningForWakeWord else { return }
        if logStart {
            print("🎧 [QAVoiceService] Listening for wake word…")
        }
        startRecognition(for: .keywordListening)
    }
    
    func startDictation() {
        guard speechRecognizer?.isAvailable == true else {
            onError?(VoiceError.speechRecognizerUnavailable)
            return
        }
        guard isSpeechPermissionGranted, isRecordPermissionGranted else {
            onError?(VoiceError.permissionDenied)
            return
        }
        isListeningForWakeWord = false
        startRecognition(for: .dictating)
    }
    
    func stop() {
        tearDownRecognition()
        deactivateAudioSession()
        mode = .idle
        isListeningForWakeWord = false
    }
    
    func cancelDictationAndResumeKeywordListening() {
        tearDownRecognition()
        isListeningForWakeWord = false
        print("🎧 [QAVoiceService] Returning to wake-word listening.")
        startKeywordListening()
    }
    
    // MARK: - Permissions
    
    private func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                completion(true)
            case .denied, .restricted, .notDetermined:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
    
    private func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - Recognition Lifecycle
    
    private func startRecognition(for mode: Mode) {
        guard configureAudioSession() else {
            onError?(VoiceError.audioEngineError)
            return
        }
        
        tearDownRecognition()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasInstalledTap = true
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            onError?(VoiceError.audioEngineError)
            return
        }
        
        self.mode = mode
        isListeningForWakeWord = (mode == .keywordListening)
        
        var currentTask: SFSpeechRecognitionTask?
        currentTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            guard let currentTask, self.recognitionTask === currentTask else { return }
            
            if let error {
                if !self.handleSpeechRecognitionError(error as NSError) {
                    self.onError?(error)
                    self.transitionToIdle()
                }
                return
            }
            
            guard let result else { return }
            self.handleRecognitionResult(result)
            
            if result.isFinal {
                switch self.mode {
                case .keywordListening:
                    self.restartKeywordListening()
                case .dictating:
                    self.finishDictation()
                case .idle:
                    break
                }
            }
        }
        recognitionTask = currentTask
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString
        
        switch mode {
        case .keywordListening:
            guard !transcript.isEmpty else { return }
            logKeywordTranscript(transcript)
            let simplifiedTranscript = transcript.replacingOccurrences(of: " ", with: "")
            let simplifiedWake = wakeWord.replacingOccurrences(of: " ", with: "")
            if simplifiedTranscript.localizedCaseInsensitiveContains(simplifiedWake) {
                onKeywordDetected?()
            }
        case .dictating:
            guard !transcript.isEmpty else { return }
            onDictationTextChanged?(transcript)
        case .idle:
            break
        }
    }
    
    private func finishDictation() {
        tearDownRecognition()
        mode = .idle
        isListeningForWakeWord = false
        onDictationFinished?()
    }
    
    private func restartKeywordListening() {
        tearDownRecognition()
        startKeywordListening(logStart: false)
    }
    
    private func transitionToIdle() {
        tearDownRecognition()
        mode = .idle
        isListeningForWakeWord = false
    }
    
    private func tearDownRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        isListeningForWakeWord = false
    }
    
    private func configureAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.duckOthers, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            return true
        } catch {
            onError?(error)
            return false
        }
    }
    
    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            onError?(error)
        }
    }
    
    private func logKeywordTranscript(_ transcript: String) {
        if let logger = keywordTranscriptLogger {
            logger(transcript)
        } else {
            print("🎧 [QAVoiceService] Keyword transcript: \(transcript)")
        }
    }
    
    private func handleSpeechRecognitionError(_ error: NSError) -> Bool {
        guard Self.speechRecognitionErrorDomains.contains(error.domain) else {
            return false
        }
        
        let description = error.localizedDescription.lowercased()
        let isSilenceTimeout = description.contains("no speech detected") || description.contains("speech timeout")
        let isCancellation = description.contains("canceled")
        
        if isSilenceTimeout {
            switch mode {
            case .keywordListening:
                restartKeywordListening()
            case .dictating:
                finishDictation()
            case .idle:
                break
            }
            return true
        }
        
        if isCancellation {
            transitionToIdle()
            return true
        }
        
        return false
    }
    
}
private extension QAKeywordVoiceService {
    /// Known Foundation domain identifiers that Apple uses for speech recognizer errors.
    ///
    /// - `kAFAssistantErrorDomain` is what iOS reports at runtime.
    /// - `SFSpeechRecognitionErrorDomain` is the symbolic name referenced in documentation.
    ///
    /// Some SDK versions expose only the raw string, so we check against both values instead of
    /// relying on a single framework constant that may be missing on certain platforms.
    static let speechRecognitionErrorDomains: Set<String> = [
        "SFSpeechRecognitionErrorDomain",
        "kAFAssistantErrorDomain"
    ]
}

