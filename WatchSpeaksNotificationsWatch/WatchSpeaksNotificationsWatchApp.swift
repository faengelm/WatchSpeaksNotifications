import SwiftUI
import WatchKit
import WatchConnectivity
import AVFoundation
import UserNotifications

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Set ourselves as notification delegate so banners show even when app is active
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

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

// MARK: - Notification Delegate

/// Handles notification presentation and tap actions on watchOS.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Show banner + sound even when the app is in the foreground or during a background task.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// User tapped the notification — app opens to foreground, scenePhase triggers speakPendingIfNeeded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

@main
struct WatchSpeaksNotificationsWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }

        // Long-look notification scene — speaks announcement when notification is displayed
        WKNotificationScene(controller: NotificationController.self, category: "ANNOUNCEMENT")
    }
}
