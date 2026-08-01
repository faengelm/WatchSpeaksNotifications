import SwiftUI

@main
struct WatchSpeaksNotificationsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .onAppear {
                    WatchConnectivityManager.shared.start()
                }
        }
    }
}
