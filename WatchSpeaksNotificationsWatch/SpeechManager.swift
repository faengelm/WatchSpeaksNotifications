import Foundation
import AVFoundation
import WatchKit

class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingAnnouncements: [String] = []
    private var extendedSession: WKExtendedRuntimeSession?

    @Published var isSpeaking = false
    @Published var lastSpokenText: String?

    var speechRate: Float = 0.5
    var speechPitch: Float = 1.0

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

        performSpeak(fullText)
    }

    private func performSpeak(_ text: String) {
        startExtendedSession()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[Speech] Audio session error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        utterance.voice = AVSpeechSynthesisVoice(
            language: Locale.current.language.languageCode?.identifier ?? "en"
        )
        utterance.preUtteranceDelay = 0.3

        isSpeaking = true
        lastSpokenText = text
        synthesizer.speak(utterance)
    }

    // MARK: - Extended Runtime Session

    private func startExtendedSession() {
        guard extendedSession == nil || extendedSession?.state == .invalid else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
    }

    private func endExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let next = pendingAnnouncements.first {
            pendingAnnouncements.removeFirst()
            performSpeak(next)
        } else {
            isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            endExtendedSession()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        pendingAnnouncements.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        endExtendedSession()
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension SpeechManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        self.extendedSession = nil
    }
}
