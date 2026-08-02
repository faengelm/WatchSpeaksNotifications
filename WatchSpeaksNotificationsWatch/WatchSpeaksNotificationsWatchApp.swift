import SwiftUI
import WatchKit
import WatchConnectivity
import AVFoundation

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchConnectivityManager.shared.start()
        Self.scheduleNextRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        let manager = WatchConnectivityManager.shared

        // Pre-activate audio so speech can start immediately
        SpeechManager.shared.activateAudioSession()

        for task in backgroundTasks {
            switch task {
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                manager.startBackgroundSession()
                manager.addPendingTask(connectivityTask)

                DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                    manager.completeTask(connectivityTask)
                }

            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Check for pending WCSession data or application context announcements
                manager.processPendingData()

                if WCSession.default.activationState == .activated,
                   WCSession.default.hasContentPending {
                    manager.startBackgroundSession()
                    manager.addPendingTask(refreshTask)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                        manager.completeTask(refreshTask)
                    }
                } else {
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }

        Self.scheduleNextRefresh()
    }

    static func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 5 * 60),
            userInfo: nil,
            scheduledCompletion: { _ in }
        )
    }
}

@main
struct WatchSpeaksNotificationsWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
