import Foundation
import AVFoundation
import WatchKit

class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    private var synthesizer = AVSpeechSynthesizer()
    private var pendingAnnouncements: [String] = []
    private var retryText: String?
    private var retryCount = 0
    private static let maxRetries = 1
    private var speechTimeoutWork: DispatchWorkItem?
    private static let speechTimeout: TimeInterval = 10

    @Published var isSpeaking = false
    @Published var lastSpokenText: String?
    @Published var lastError: String?

    var speechRate: Float = 0.5
    var speechPitch: Float = 1.0
    var onComplete: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, source: String? = nil, prefixSource: Bool = true) {
        let fullText: String
        if let source = source, prefixSource, source != "Test" {
            fullText = "\(source): \(text)"
        } else {
            fullText = text
        }

        if synthesizer.isSpeaking {
            pendingAnnouncements.append(fullText)
            return
        }

        retryCount = 0
        performSpeak(fullText)
    }

    private func performSpeak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])

        // Async activation — waits for the audio route to be ready (SmartBottleTalk pattern)
        session.activate(options: []) { [weak self] activated, error in
            guard activated, let self else {
                DispatchQueue.main.async {
                    self?.lastError = "Audio: \(error?.localizedDescription ?? "not activated")"
                    self?.finishSpeaking()
                }
                return
            }

            DispatchQueue.main.async {
                let utterance = AVSpeechUtterance(string: text)
                utterance.rate = self.speechRate
                utterance.pitchMultiplier = self.speechPitch
                utterance.volume = 1.0
                utterance.preUtteranceDelay = 0.3
                utterance.postUtteranceDelay = 0.2

                if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                    utterance.voice = voice
                }

                self.retryText = text
                self.isSpeaking = true
                self.lastSpokenText = text
                self.lastError = nil
                self.synthesizer.speak(utterance)
                self.startSpeechTimeout()
            }
        }
    }

    // MARK: - Speech Timeout

    private func resetSynthesizer() {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        print("[Speech] Synthesizer recreated")
    }

    private func startSpeechTimeout() {
        speechTimeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isSpeaking else { return }
            print("[Speech] Timeout — recreating stuck synthesizer")
            self.resetSynthesizer()
            self.pendingAnnouncements.removeAll()
            self.finishSpeaking()
        }
        speechTimeoutWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SpeechManager.speechTimeout, execute: work
        )
    }

    private func cancelSpeechTimeout() {
        speechTimeoutWork?.cancel()
        speechTimeoutWork = nil
    }

    /// Force-cancel speech — called when user taps "Speaking..." status
    func cancelSpeech() {
        resetSynthesizer()
        pendingAnnouncements.removeAll()
        cancelSpeechTimeout()
        finishSpeaking()
    }

    private func finishSpeaking() {
        cancelSpeechTimeout()
        isSpeaking = false
        retryText = nil
        retryCount = 0
        onComplete?()
        onComplete = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if let next = self.pendingAnnouncements.first {
                self.pendingAnnouncements.removeFirst()
                self.retryCount = 0
                self.performSpeak(next)
            } else {
                self.finishSpeaking()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if let text = self.retryText, self.retryCount < SpeechManager.maxRetries {
                self.retryCount += 1
                print("[Speech] Cancelled, retrying (\(self.retryCount)/\(SpeechManager.maxRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.performSpeak(text)
                }
            } else {
                self.pendingAnnouncements.removeAll()
                self.finishSpeaking()
            }
        }
    }
}
