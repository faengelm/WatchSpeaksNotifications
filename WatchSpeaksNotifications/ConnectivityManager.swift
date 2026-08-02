import Foundation
import WatchConnectivity
import SwiftUI

struct NotificationSource: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let icon: String
    var isEnabled: Bool

    static let defaults: [NotificationSource] = [
        NotificationSource(id: "messages", name: "Messages", icon: "message.fill", isEnabled: true),
        NotificationSource(id: "mail", name: "Mail", icon: "envelope.fill", isEnabled: true),
        NotificationSource(id: "calendar", name: "Calendar", icon: "calendar", isEnabled: true),
        NotificationSource(id: "reminders", name: "Reminders", icon: "checklist", isEnabled: true),
        NotificationSource(id: "phone", name: "Phone", icon: "phone.fill", isEnabled: true),
        NotificationSource(id: "facetime", name: "FaceTime", icon: "video.fill", isEnabled: false),
        NotificationSource(id: "news", name: "News", icon: "newspaper.fill", isEnabled: false),
        NotificationSource(id: "health", name: "Health", icon: "heart.fill", isEnabled: true),
        NotificationSource(id: "home", name: "Home", icon: "house.fill", isEnabled: false),
        NotificationSource(id: "weather", name: "Weather", icon: "cloud.sun.fill", isEnabled: false),
        NotificationSource(id: "shortcuts", name: "Shortcuts", icon: "square.on.square", isEnabled: true),
        NotificationSource(id: "other", name: "Other Apps", icon: "app.fill", isEnabled: false),
    ]
}

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

    // MARK: - Notification Sources

    @Published var sources: [NotificationSource] = [] {
        didSet { saveSources() }
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
        loadSources()
        loadLog()
        start()
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
        guard isSourceEnabled(source) else { return }
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
    }

    func sendTestAnnouncement() {
        sendAnnouncement(
            text: "This is a test announcement from Watch Speaks Notifications",
            source: "Test"
        )
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

    // MARK: - Source Filtering

    func isSourceEnabled(_ source: String) -> Bool {
        let normalized = source.lowercased()
        if normalized == "test" { return true }
        if let match = sources.first(where: {
            $0.name.lowercased() == normalized || $0.id == normalized
        }) {
            return match.isEnabled
        }
        return sources.first(where: { $0.id == "other" })?.isEnabled ?? true
    }

    func toggleSource(_ id: String, enabled: Bool) {
        if let idx = sources.firstIndex(where: { $0.id == id }) {
            sources[idx].isEnabled = enabled
        }
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

    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: "notificationSources")
        }
    }

    private func loadSources() {
        if let data = UserDefaults.standard.data(forKey: "notificationSources"),
           let saved = try? JSONDecoder().decode([NotificationSource].self, from: data) {
            sources = saved
        } else {
            sources = NotificationSource.defaults
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
