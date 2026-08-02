import Foundation
import AVFoundation
import WatchKit

class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingAnnouncements: [String] = []
    private var retryText: String?
    private var retryCount = 0
    private static let maxRetries = 2

    @Published var isSpeaking = false
    @Published var lastSpokenText: String?
    @Published var lastError: String?

    var speechRate: Float = 0.5
    var speechPitch: Float = 1.0
    var onComplete: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        activateAudioSession()
    }

    func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio,
                                    options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[Speech] Audio pre-activation: \(error)")
        }
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
        // Activate audio session synchronously before speaking
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio,
                                    options: [.duckOthers])
            try session.setActive(true)
        } catch {
            DispatchQueue.main.async {
                self.lastError = "Audio: \(error.localizedDescription)"
            }
            print("[Speech] Audio session error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.2

        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        // Track for retry if speech produces no audio
        retryText = text

        // Speak immediately — no nested async dispatch
        isSpeaking = true
        lastSpokenText = text
        lastError = nil
        synthesizer.speak(utterance)
    }

    private func finishSpeaking() {
        isSpeaking = false
        retryText = nil
        retryCount = 0
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
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
            // Retry on cancel — watchOS sometimes cancels when audio route isn't ready
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
