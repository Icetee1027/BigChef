import Foundation
import UIKit

private struct VoiceCommandDetectionResult {
    let command: CookVoiceCommand
    let normalizedText: String
    let matchRange: Range<String.Index>
}

extension CookViewController {
    func setupQAVoiceService() {
        qaVoiceService.keywordTranscriptLogger = { [weak self] transcript in
            self?.handleKeywordTranscript(transcript)
        }

        qaVoiceService.onKeywordDetected = { [weak self] in
            DispatchQueue.main.async {
                self?.handleWakeWordDetected()
            }
        }

        qaVoiceService.onDictationTextChanged = { [weak self] text in
            DispatchQueue.main.async {
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                if self.baselineDictationTranscript == nil {
                    self.baselineDictationTranscript = trimmed
                    self.lastRawDictation = trimmed
                    print("🗣️ [QAVoiceService] Captured baseline transcript: \(trimmed)")

                    if self.handleVoiceCommandIfNeeded(from: trimmed) {
                        return
                    }

                    return
                }

                if self.handleVoiceCommandIfNeeded(from: trimmed) {
                    self.lastRawDictation = trimmed
                    return
                }

                if trimmed == self.lastRawDictation {
                    return
                }

                print("🗣️ [QAVoiceService] Current transcription: \(trimmed)")
                var processed = trimmed

                if let baseline = self.baselineDictationTranscript {
                    let baselineTrimmed = baseline.trimmingCharacters(in: .whitespacesAndNewlines)
                    if baselineTrimmed.count > 1 {
                        if processed.hasPrefix(baseline) {
                            processed.removeFirst(min(baseline.count, processed.count))
                        } else if processed.hasPrefix(baselineTrimmed) {
                            processed.removeFirst(min(baselineTrimmed.count, processed.count))
                        } else {
                            let commonPrefix = processed.commonPrefix(with: baselineTrimmed)
                            if commonPrefix.count >= baselineTrimmed.count - 1 {
                                processed.removeFirst(min(commonPrefix.count, processed.count))
                            }
                        }
                    }
                }

                while processed.hasPrefix(self.qaWakeWord) {
                    processed.removeFirst(self.qaWakeWord.count)
                    processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !processed.isEmpty else {
                    self.lastRawDictation = trimmed
                    return
                }

                if self.handleVoiceCommandIfNeeded(from: processed) {
                    return
                }

                self.lastRawDictation = trimmed

                let existing = self.pendingDraftQuestion
                var newDraft = existing

                if existing.isEmpty {
                    newDraft = processed
                } else if processed.count >= existing.count, processed.hasPrefix(existing) {
                    let additionSubstring = processed.dropFirst(existing.count)
                    let addition = String(additionSubstring)
                    if addition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return
                    }
                    let separator = existing.last?.isWhitespace == true || addition.first?.isWhitespace == true ? "" : " "
                    newDraft = existing + separator + addition
                } else if existing.count > processed.count, existing.hasPrefix(processed) {
                    self.pendingDraftQuestion = processed
                    if let bubble = self.qaInputBubbleView {
                        bubble.setDraftText(processed)
                    } else {
                        self.showQAInputBubble(voiceTriggered: true)
                        self.qaInputBubbleView?.setDraftText(processed)
                    }
                    return
                } else {
                    newDraft = processed
                }

                if newDraft == existing {
                    return
                }

                self.pendingDraftQuestion = newDraft
                if let bubble = self.qaInputBubbleView {
                    bubble.setDraftText(newDraft)
                } else {
                    self.showQAInputBubble(voiceTriggered: true)
                    self.qaInputBubbleView?.setDraftText(newDraft)
                }
            }
        }

        qaVoiceService.onDictationFinished = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isVoiceDictationActive = false
                self.baselineDictationTranscript = nil
                self.lastRawDictation = ""
                self.scheduleNextListeningCycle()
            }
        }

        qaVoiceService.onError = { [weak self] error in
            let message = error.localizedDescription
            if !message.localizedCaseInsensitiveContains("canceled") {
                print("⚠️ [QAVoiceService] Error: \(message)")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isVoiceDictationActive = false
                self.baselineDictationTranscript = nil
                self.lastRawDictation = ""
                self.scheduleNextListeningCycle()
            }
        }

        if CookAssistResourcePreloader.shared.hasVoicePermission {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                print("🎤 [QAVoiceService] Permissions already granted. Resume keyword listening.")
                self.qaVoiceService.startKeywordListening()
            }
        } else {
            qaVoiceService.requestPermissions { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        print("🎤 [QAVoiceService] Permissions granted. Start keyword listening.")
                        self.qaVoiceService.startKeywordListening()
                    } else {
                        print("🚫 [QAVoiceService] Permissions denied.")
                    }
                }
            }
        }
    }

    private func handleVoiceCommandIfNeeded(from text: String) -> Bool {
        guard let detection = detectVoiceCommand(in: text) else { return false }

        let command = detection.command
        print("🎯 [QAVoiceService] Detected voice command: \(command.rawValue) (input: \(text))")

        let inputBubble = qaInputBubbleView
        let hasInputBubble = inputBubble != nil
        let isInputActive = inputBubble?.isInputActive ?? false

        let bubbleHasUserDraft: Bool = {
            let draft = inputBubble?.currentDraftText().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pending = pendingDraftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            return !draft.isEmpty || !pending.isEmpty
        }()

        let hasExtraCharactersBeyondCommand = !normalizedRemainder(afterRemoving: detection).isEmpty

        switch command {
        case .nextStep, .previousStep:
            if hasInputBubble && isInputActive && (bubbleHasUserDraft || hasExtraCharactersBeyondCommand) {
                print("📝 [QAVoiceService] Input bubble active, treating command as dictation text.")
                return false
            }

            guard shouldProcessVoiceCommand(command) else { return true }

            if hasInputBubble {
                dismissQABubble(animated: false, persistDraft: false)
            }

            performVoiceCommand(command)
            return true

        case .clear:
            guard hasInputBubble else {
                print("ℹ️ [QAVoiceService] Ignoring '清除' command because input bubble is not visible.")
                return true
            }

            guard shouldProcessVoiceCommand(command) else { return true }
            performVoiceCommand(command)
            return true

        case .submit:
            guard hasInputBubble else {
                print("ℹ️ [QAVoiceService] Ignoring '送出' command because input bubble is not visible.")
                return true
            }

            guard shouldProcessVoiceCommand(command) else { return true }
            performVoiceCommand(command)
            return true
        }
    }

    private func handleKeywordTranscript(_ transcript: String) {
        guard qaInputBubbleView == nil else { return }
        print("🎧 [QAVoiceService] Keyword transcript: \(transcript)")

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let detection = detectVoiceCommand(in: trimmed) else { return }
        let remainder = normalizedRemainder(afterRemoving: detection)
        guard remainder.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.qaInputBubbleView == nil else { return }
            _ = self.handleVoiceCommandIfNeeded(from: trimmed)
        }
    }

    private func detectVoiceCommand(in text: String) -> VoiceCommandDetectionResult? {
        if let directMatch = CookVoiceCommand(rawValue: text) {
            let normalized = normalizeVoiceCommandText(text)
            let range = normalized.startIndex..<normalized.endIndex
            return VoiceCommandDetectionResult(command: directMatch, normalizedText: normalized, matchRange: range)
        }

        let normalized = normalizeVoiceCommandText(text)
        guard !normalized.isEmpty else { return nil }

        var bestMatch: (command: CookVoiceCommand, range: Range<String.Index>)?

        for command in CookVoiceCommand.allCases {
            let normalizedCommand = normalizeVoiceCommandText(command.rawValue)
            guard !normalizedCommand.isEmpty else { continue }

            var searchRange = normalized.startIndex..<normalized.endIndex
            while let range = normalized.range(of: normalizedCommand, options: [], range: searchRange) {
                if let currentBest = bestMatch {
                    if range.upperBound > currentBest.range.upperBound {
                        bestMatch = (command, range)
                    }
                } else {
                    bestMatch = (command, range)
                }

                searchRange = range.upperBound..<normalized.endIndex
            }
        }

        guard let match = bestMatch else { return nil }
        return VoiceCommandDetectionResult(command: match.command, normalizedText: normalized, matchRange: match.range)
    }

    private func normalizedRemainder(afterRemoving detection: VoiceCommandDetectionResult) -> String {
        var remainder = detection.normalizedText
        remainder.removeSubrange(detection.matchRange)

        let wakeNormalized = normalizeVoiceCommandText(qaWakeWord)
        if !wakeNormalized.isEmpty {
            while let wakeRange = remainder.range(of: wakeNormalized) {
                remainder.removeSubrange(wakeRange)
            }
        }

        return remainder
    }

    private func normalizeVoiceCommandText(_ text: String) -> String {
        let removalSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，。！？、,.!?;；：:「」『』()（）"))
        let filteredScalars = text.unicodeScalars.filter { !removalSet.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    private func shouldProcessVoiceCommand(_ command: CookVoiceCommand) -> Bool {
        let now = Date()
        if let last = lastVoiceCommandExecution,
           last.command == command,
           now.timeIntervalSince(last.timestamp) < 1.0 {
            return false
        }

        lastVoiceCommandExecution = (command, now)
        return true
    }

    private func performVoiceCommand(_ command: CookVoiceCommand) {
        let execute = { [weak self] in
            guard let self else { return }

            print("🚦 [QAVoiceService] Executing voice command: \(command.rawValue)")

            switch command {
            case .nextStep:
                guard self.qaHasNextStep() else {
                    self.presentToast("已經是最後一步")
                    self.resetVoiceDictationAfterCommand(resumeDictation: false)
                    return
                }
                self.nextStep()
                self.presentToast(command.rawValue)
                self.resetVoiceDictationAfterCommand(resumeDictation: false)

            case .previousStep:
                guard self.qaHasPreviousStep() else {
                    self.presentToast("已經是第一步")
                    self.resetVoiceDictationAfterCommand(resumeDictation: false)
                    return
                }
                self.prevStep()
                self.presentToast(command.rawValue)
                self.resetVoiceDictationAfterCommand(resumeDictation: false)

            case .submit:
                guard let bubble = self.qaInputBubbleView else {
                    self.presentToast("目前沒有問題可以送出")
                    self.resetVoiceDictationAfterCommand(resumeDictation: false)
                    return
                }
                bubble.clearValidationError()
                bubble.onSubmit?(bubble.currentDraftText())
                bubble.setDraftText("")
                self.pendingDraftQuestion = ""

            case .clear:
                guard let bubble = self.qaInputBubbleView else {
                    self.pendingDraftQuestion = ""
                    self.presentToast("目前沒有內容可以清除")
                    self.resetVoiceDictationAfterCommand(resumeDictation: false)
                    return
                }

                bubble.clearValidationError()
                bubble.onClear?()
                bubble.setDraftText("")
                self.presentToast("已清除")
                self.resetVoiceDictationAfterCommand(resumeDictation: true)
            }
        }

        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.async(execute: execute)
        }
    }

    private func resetVoiceDictationAfterCommand(resumeDictation: Bool) {
        qaVoiceService.cancelDictationAndResumeKeywordListening()
        isVoiceDictationActive = false
        baselineDictationTranscript = nil
        lastRawDictation = ""

        if resumeDictation {
            scheduleNextListeningCycle()
        }
    }

    func handleWakeWordDetected() {
        guard !isVoiceDictationActive else { return }
        print("🔥 [QAVoiceService] Wake word detected, entering dictation.")
        pendingDraftQuestion = ""
        baselineDictationTranscript = nil
        lastRawDictation = ""
        if let bubble = qaInputBubbleView {
            bubble.setDraftText("")
            bubble.focus()
            beginVoiceDictation()
        } else {
            showQAInputBubble(voiceTriggered: true)
        }
    }

    func beginVoiceDictationIfNeededAfterBubble() {
        guard shouldStartDictationAfterBubblePresented else { return }
        shouldStartDictationAfterBubblePresented = false
        beginVoiceDictation()
    }

    func beginVoiceDictation() {
        guard !isVoiceDictationActive else { return }
        isVoiceDictationActive = true
        baselineDictationTranscript = nil
        lastRawDictation = ""
        qaVoiceService.startDictation()
    }

    func scheduleNextListeningCycle() {
        let hasInputBubble = qaInputBubbleView != nil
        let delay: TimeInterval = hasInputBubble ? 0.2 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if self.qaInputBubbleView != nil {
                guard !self.isVoiceDictationActive else { return }
                self.beginVoiceDictation()
            } else {
                self.qaVoiceService.startKeywordListening()
            }
        }
    }
}
