import Foundation
import WatchConnectivity
import SwiftUI
import UserNotifications

class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()

    // MARK: - Watch State (received)

    @Published var isWatchPaired = false
    @Published var isWatchReachable = false
    @Published var watchVersion: String?
    @Published var watchBuild: String?
    @Published var lastSpokenText: String?
    @Published var isSpeaking = false

    // MARK: - Settings (synced to Watch)

    @Published var speechRate: Float = 0.5 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speechRate")
            syncSettings()
        }
    }

    @Published var speechPitch: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(speechPitch, forKey: "speechPitch")
            syncSettings()
        }
    }

    @Published var announcementsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(announcementsEnabled, forKey: "announcementsEnabled")
            syncSettings()
        }
    }

    @Published var prefixSourceName: Bool = true {
        didSet {
            UserDefaults.standard.set(prefixSourceName, forKey: "prefixSourceName")
            syncSettings()
        }
    }

    // MARK: - Announcement Log

    @Published var announcementLog: [AnnouncementEntry] = []

    struct AnnouncementEntry: Identifiable, Codable {
        let id: UUID
        let text: String
        let source: String
        let timestamp: Date
        let delivered: Bool
    }

    // MARK: - Init

    override init() {
        super.init()
        loadSettings()
        loadLog()
        start()
        setupNotifications()
    }

    // MARK: - Notification Setup (for Watch mirroring)

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("[Phone] Notification permission: \(granted), error: \(String(describing: error))")
        }
        // Register category so watchOS routes mirrored notifications
        // to the Watch's WKNotificationScene / NotificationController
        let category = UNNotificationCategory(
            identifier: "ANNOUNCEMENT",
            actions: [],
            intentIdentifiers: [],
            options: [])
        center.setNotificationCategories([category])
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate (required)

    private var activationContinuations: [CheckedContinuation<Void, Never>] = []

    func waitForActivation() async {
        if WCSession.default.activationState == .activated { return }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if WCSession.default.activationState == .activated {
                    continuation.resume()
                } else {
                    self.activationContinuations.append(continuation)
                }
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchReachable = session.isReachable
        }
        if activationState == .activated {
            let pending = activationContinuations
            activationContinuations.removeAll()
            for continuation in pending {
                continuation.resume()
            }
            syncSettings()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    // MARK: - Send Announcement to Watch

    private var latestAnnouncementForContext: [String: Any]?

    func sendAnnouncement(text: String, source: String) {
        guard announcementsEnabled else { return }
        guard WCSession.default.activationState == .activated else { return }

        let messageId = UUID().uuidString

        let message: [String: Any] = [
            "type": "announcement",
            "id": messageId,
            "text": text,
            "source": source,
            "timestamp": Date().timeIntervalSince1970,
            "prefixSource": prefixSourceName,
        ]

        let entry = AnnouncementEntry(
            id: UUID(),
            text: text,
            source: source,
            timestamp: Date(),
            delivered: WCSession.default.isReachable
        )

        DispatchQueue.main.async {
            self.announcementLog.insert(entry, at: 0)
            if self.announcementLog.count > 50 {
                self.announcementLog = Array(self.announcementLog.prefix(50))
            }
            self.saveLog()
        }

        // Channel 1: Queue via transferUserInfo for guaranteed delivery
        WCSession.default.transferUserInfo(message)

        // Channel 2: Try sendMessage for immediate delivery when Watch app is active
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }

        // Channel 3: Embed in application context so Watch gets it on ANY wake-up
        latestAnnouncementForContext = message
        syncSettings()

        // Channel 4: Post iPhone notification — watchOS mirrors it to Watch,
        // triggering WKNotificationScene / NotificationController for reliable
        // background speech (SmartBottleTalk pattern)
        postAnnouncementNotification(text: text, source: source)
    }

    private func postAnnouncementNotification(text: String, source: String) {
        let content = UNMutableNotificationContent()
        content.title = source == "Test" ? "Watch Speaks" : source
        content.body = text
        content.categoryIdentifier = "ANNOUNCEMENT"
        content.userInfo = ["spokenText": text]
        content.sound = .default
        content.interruptionLevel = .timeSensitive   // break through focus modes

        let request = UNNotificationRequest(
            identifier: "announce-\(UUID().uuidString)",
            content: content,
            trigger: nil  // immediate delivery (SmartBottleTalk pattern)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Phone] Notification error: \(error)")
            }
        }
    }

    func sendTestAnnouncement() {
        sendAnnouncement(
            text: "This is a test announcement from Watch Speaks",
            source: "Test"
        )
    }

    /// Schedule a delayed test notification — gives the user time to lock their
    /// iPhone so the notification mirrors to Watch for background speech testing.
    /// Only posts the notification (no WCSession), purely testing the mirroring path.
    func scheduleDelayedTest(seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Watch Speaks"
        content.body = "This is a test announcement from Watch Speaks"
        content.categoryIdentifier = "ANNOUNCEMENT"
        content.userInfo = ["spokenText": "This is a test announcement from Watch Speaks"]
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "delayed-test-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, seconds), repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Phone] Delayed test notification error: \(error)")
            }
        }
    }

    // MARK: - Receive State from Watch

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard applicationContext["source"] as? String == "watch" else { return }
        DispatchQueue.main.async {
            self.isSpeaking = applicationContext["isSpeaking"] as? Bool ?? false
            self.lastSpokenText = applicationContext["lastSpokenText"] as? String
            self.watchVersion = applicationContext["watchVersion"] as? String
            self.watchBuild = applicationContext["watchBuild"] as? String
        }
    }

    // MARK: - Settings Sync

    private func syncSettings() {
        guard WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [
            "source": "phone",
            "speechRate": speechRate,
            "speechPitch": speechPitch,
            "announcementsEnabled": announcementsEnabled,
            "prefixSourceName": prefixSourceName,
        ]
        if let announcement = latestAnnouncementForContext {
            context["latestAnnouncement"] = announcement
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Persistence

    private func loadSettings() {
        if UserDefaults.standard.object(forKey: "speechRate") != nil {
            speechRate = UserDefaults.standard.float(forKey: "speechRate")
        }
        if UserDefaults.standard.object(forKey: "speechPitch") != nil {
            speechPitch = UserDefaults.standard.float(forKey: "speechPitch")
        }
        if UserDefaults.standard.object(forKey: "announcementsEnabled") != nil {
            announcementsEnabled = UserDefaults.standard.bool(forKey: "announcementsEnabled")
        }
        if UserDefaults.standard.object(forKey: "prefixSourceName") != nil {
            prefixSourceName = UserDefaults.standard.bool(forKey: "prefixSourceName")
        }
    }

    private func saveLog() {
        if let data = try? JSONEncoder().encode(announcementLog) {
            UserDefaults.standard.set(data, forKey: "announcementLog")
        }
    }

    private func loadLog() {
        if let data = UserDefaults.standard.data(forKey: "announcementLog"),
           let log = try? JSONDecoder().decode([AnnouncementEntry].self, from: data) {
            announcementLog = log
        }
    }

    func clearLog() {
        announcementLog.removeAll()
        saveLog()
    }
}
