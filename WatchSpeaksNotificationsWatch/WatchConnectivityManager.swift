import Foundation
import WatchConnectivity
import WatchKit
import UserNotifications

/// Minimal Watch connectivity — matches SmartBottleTalk's architecture.
/// Receives settings from iPhone and handles foreground speech.
/// Background speech is handled entirely by iPhone notification mirroring →
/// WKNotificationScene → NotificationController (no Watch-side notifications).
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var announcementsEnabled = true
    @Published var prefixSourceName = true
    @Published var notificationsAllowed: Bool?

    private var hasStarted = false
    private var processedIds = Set<String>()

    // Pending speech for when app returns to foreground
    private(set) var pendingSpeech: (text: String, source: String?, prefixSource: Bool)?

    override init() {
        super.init()
        start()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        requestNotificationPermission()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Notification Permission

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            DispatchQueue.main.async {
                self.notificationsAllowed = granted
            }
            print("[Watch] Notification permission: \(granted), error: \(String(describing: error))")
        }
    }

    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsAllowed = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if activationState == .activated {
            sendState()
            processPendingData()
        }
    }

    // MARK: - Process Pending Data

    func processPendingData() {
        guard WCSession.default.activationState == .activated else { return }

        let ctx = WCSession.default.receivedApplicationContext
        if !ctx.isEmpty, ctx["source"] as? String == "phone" {
            session(WCSession.default, didReceiveApplicationContext: ctx)
        }
    }

    // MARK: - Speak Pending on Foreground

    /// Clears pending speech (called by NotificationController when long-look speaks it).
    func clearPendingSpeech() {
        pendingSpeech = nil
    }

    /// Called when the app enters the foreground. If there is a pending
    /// announcement that couldn't be spoken in the background, speak it now.
    func speakPendingIfNeeded() {
        guard let pending = pendingSpeech else { return }
        pendingSpeech = nil
        SpeechManager.shared.speak(
            pending.text, source: pending.source, prefixSource: pending.prefixSource
        )
        WKInterfaceDevice.current().play(.click)
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
            if let announcement = applicationContext["latestAnnouncement"] as? [String: Any] {
                self.handleIncoming(announcement)
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

        if let id = info["id"] as? String {
            guard !processedIds.contains(id) else { return }
            processedIds.insert(id)
            if processedIds.count > 100 {
                processedIds.removeAll()
            }
        }

        let text = info["text"] as? String ?? ""
        let source = info["source"] as? String
        let prefixSource = info["prefixSource"] as? Bool ?? prefixSourceName

        guard !text.isEmpty else { return }

        DispatchQueue.main.async {
            let isForeground = WKApplication.shared().applicationState == .active

            if isForeground {
                // Foreground: haptic + speak directly
                WKInterfaceDevice.current().play(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    SpeechManager.shared.speak(text, source: source, prefixSource: prefixSource)
                }
            } else {
                // Background: store for foreground recovery, then post a local
                // notification so WKNotificationScene presents the long-look
                // (NotificationController.didReceive speaks the text).
                // NO willPresent handler exists, so the notification flows
                // naturally to WKNotificationScene.
                self.pendingSpeech = (text: text, source: source, prefixSource: prefixSource)
                self.postAnnouncementNotification(text: text, source: source)
            }

            self.sendState()
        }
    }

    // MARK: - Local Notifications (triggers WKNotificationScene)

    private func postAnnouncementNotification(text: String, source: String?) {
        let content = UNMutableNotificationContent()
        content.title = source ?? "Watch Speaks"
        content.body = text
        content.categoryIdentifier = "ANNOUNCEMENT"
        content.userInfo = ["spokenText": text]
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "announce-\(UUID().uuidString)",
            content: content,
            trigger: nil  // immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Watch] Notification error: \(error)")
            } else {
                print("[Watch] Posted announcement notification")
            }
        }
    }
}
