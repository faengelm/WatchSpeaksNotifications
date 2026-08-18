import SwiftUI
import WatchKit

/// Minimal Watch app — matches SmartBottleTalk's proven architecture.
/// NO WKApplicationDelegate, NO UNUserNotificationCenterDelegate.
/// iPhone posts notifications → watchOS mirrors them → WKNotificationScene
/// invokes NotificationController, which speaks the text during the long-look.
@main
struct WatchSpeaksNotificationsWatchApp: App {
    /// Touch the shared manager so WCSession activates on launch.
    private let connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }

        // Long-look notification scene — speaks announcement when notification is displayed
        WKNotificationScene(controller: NotificationController.self, category: "ANNOUNCEMENT")
    }
}
