import Foundation
import WatchConnectivity
import WatchKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var announcementsEnabled = true
    @Published var prefixSourceName = true

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if activationState == .activated {
            sendState()
        }
    }

    // MARK: - Send State to iPhone

    func sendState() {
        guard WCSession.default.activationState == .activated else { return }

        let speech = SpeechManager.shared
        let watchVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "\u{2014}"
        let watchBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "\u{2014}"

        let context: [String: Any] = [
            "source": "watch",
            "isSpeaking": speech.isSpeaking,
            "lastSpokenText": speech.lastSpokenText ?? "",
            "watchVersion": watchVersion,
            "watchBuild": watchBuild,
            "announcementsEnabled": announcementsEnabled,
        ]

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Receive Settings from iPhone

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard applicationContext["source"] as? String == "phone" else { return }
        DispatchQueue.main.async {
            let speech = SpeechManager.shared
            if let rate = applicationContext["speechRate"] as? Float {
                speech.speechRate = rate
            }
            if let pitch = applicationContext["speechPitch"] as? Float {
                speech.speechPitch = pitch
            }
            if let enabled = applicationContext["announcementsEnabled"] as? Bool {
                self.announcementsEnabled = enabled
            }
            if let prefix = applicationContext["prefixSourceName"] as? Bool {
                self.prefixSourceName = prefix
            }
        }
    }

    // MARK: - Receive Announcements from iPhone

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    private func handleIncoming(_ info: [String: Any]) {
        guard info["type"] as? String == "announcement" else { return }
        guard announcementsEnabled else { return }

        let text = info["text"] as? String ?? ""
        let source = info["source"] as? String
        let prefixSource = info["prefixSource"] as? Bool ?? prefixSourceName

        guard !text.isEmpty else { return }

        DispatchQueue.main.async {
            SpeechManager.shared.speak(text, source: source, prefixSource: prefixSource)
            WKInterfaceDevice.current().play(.notification)
            self.sendState()
        }
    }
}
