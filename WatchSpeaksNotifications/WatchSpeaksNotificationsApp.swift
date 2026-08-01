import SwiftUI

@main
struct WatchSpeaksNotificationsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    ConnectivityManager.shared.start()
                }
        }
    }
}
