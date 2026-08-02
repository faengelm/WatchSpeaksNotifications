import Foundation
import AVFoundation
import WatchKit

class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingAnnouncements: [String] = []

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
            try session.setCategory(.playback, mode: .spokenAudio)
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

        performSpeak(fullText)
    }

    private func performSpeak(_ text: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
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
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        DispatchQueue.main.async {
            self.isSpeaking = true
            self.lastSpokenText = text
            self.lastError = nil
            self.synthesizer.speak(utterance)
        }
    }

    private func finishSpeaking() {
        DispatchQueue.main.async {
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation
            )
            self.onComplete?()
            self.onComplete = nil
        }
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
                self.performSpeak(next)
            } else {
                self.finishSpeaking()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.pendingAnnouncements.removeAll()
            self.finishSpeaking()
        }
    }
}
