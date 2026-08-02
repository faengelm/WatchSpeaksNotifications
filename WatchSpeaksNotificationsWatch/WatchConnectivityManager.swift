import Foundation
import WatchConnectivity
import WatchKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var announcementsEnabled = true
    @Published var prefixSourceName = true
    @Published var lastBackgroundWake: Date?

    private var hasStarted = false
    private var processedIds = Set<String>()
    private var pendingBackgroundTasks: [WKRefreshBackgroundTask] = []
    private var extendedSession: WKExtendedRuntimeSession?

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Extended Runtime Session (background only)

    func startBackgroundSession() {
        guard extendedSession == nil || extendedSession?.state == .invalid else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
    }

    func endBackgroundSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }

    // MARK: - Background Task Management

    func addPendingTask(_ task: WKRefreshBackgroundTask) {
        pendingBackgroundTasks.append(task)
        DispatchQueue.main.async {
            self.lastBackgroundWake = Date()
        }
    }

    func completeTask(_ task: WKRefreshBackgroundTask) {
        guard pendingBackgroundTasks.contains(where: { $0 === task }) else { return }
        task.setTaskCompletedWithSnapshot(false)
        pendingBackgroundTasks.removeAll(where: { $0 === task })
        if pendingBackgroundTasks.isEmpty {
            endBackgroundSession()
        }
    }

    func completeAllPendingTasks() {
        for task in pendingBackgroundTasks {
            task.setTaskCompletedWithSnapshot(false)
        }
        pendingBackgroundTasks.removeAll()
        endBackgroundSession()
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
            SpeechManager.shared.speak(text, source: source, prefixSource: prefixSource)
            WKInterfaceDevice.current().play(.notification)

            if !self.pendingBackgroundTasks.isEmpty || self.extendedSession != nil {
                SpeechManager.shared.onComplete = { [weak self] in
                    self?.completeAllPendingTasks()
                }
            }

            self.sendState()
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchConnectivityManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        extendedSession = nil
    }
}
