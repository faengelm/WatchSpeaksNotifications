import AppIntents

struct AnnounceOnWatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Announce on Watch"
    static var description = IntentDescription(
        "Speaks text aloud on your Apple Watch speaker"
    )

    @Parameter(title: "Text to Announce")
    var text: String

    @Parameter(title: "Source App", default: "Shortcut")
    var sourceApp: String

    static var parameterSummary: some ParameterSummary {
        Summary("Announce \(\.$text) from \(\.$sourceApp) on Watch")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            ConnectivityManager.shared.sendAnnouncement(text: text, source: sourceApp)
        }
        return .result(dialog: "Announcement sent to Apple Watch")
    }
}

struct AnnounceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnnounceOnWatchIntent(),
            phrases: [
                "Announce \(\.$text) on Watch with \(.applicationName)",
                "Speak \(\.$text) on Watch with \(.applicationName)",
            ],
            shortTitle: "Announce on Watch",
            systemImageName: "speaker.wave.3.fill"
        )
    }
}
