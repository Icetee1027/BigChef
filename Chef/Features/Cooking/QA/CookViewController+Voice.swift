import Foundation
/*
extension CookViewController {
    func setupQAVoiceService() {
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
*/
