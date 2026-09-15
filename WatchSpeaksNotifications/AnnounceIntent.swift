import AppIntents
import WatchConnectivity

struct AnnounceOnWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Announce on Watch"
    static var description = IntentDescription(
        "Speaks text aloud on your Watch speaker"
    )

    @Parameter(title: "Text to Announce")
    var text: String

    @Parameter(title: "Source App", default: "Shortcut")
    var sourceApp: String

    static var parameterSummary: some ParameterSummary {
        Summary("Announce \(\.$text) from \(\.$sourceApp) on Watch")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = ConnectivityManager.shared

        // Use the async variant that AWAITS notification posting.
        // When Shortcuts launches the app, the process may be terminated
        // as soon as perform() returns — the async path keeps it alive
        // until the notification is confirmed queued by the system.
        await manager.sendAnnouncementAsync(text: text, source: sourceApp)

        return .result(dialog: "Announcement sent to Apple Watch")
    }
}

struct AnnounceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnnounceOnWatchIntent(),
            phrases: [
                "Announce on Watch with \(.applicationName)",
                "Speak on Watch with \(.applicationName)",
            ],
            shortTitle: "Announce on Watch",
            systemImageName: "speaker.wave.3.fill"
        )
    }
}
