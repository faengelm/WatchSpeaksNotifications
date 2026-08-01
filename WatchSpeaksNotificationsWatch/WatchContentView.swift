import SwiftUI

struct WatchContentView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @ObservedObject private var speech = SpeechManager.shared

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if speech.lastSpokenText != nil {
                    lastAnnouncementSection
                }
                settingsSection
            }
            .navigationTitle("Watch Speaks")
        }
    }

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: speech.isSpeaking
                      ? "speaker.wave.3.fill"
                      : "speaker.fill")
                    .font(.title3)
                    .foregroundStyle(speech.isSpeaking ? .green : .blue)
                    .symbolEffect(.variableColor, isActive: speech.isSpeaking)

                VStack(alignment: .leading, spacing: 2) {
                    Text(speech.isSpeaking ? "Speaking..." : "Ready")
                        .font(.headline)
                    Text(connectivity.announcementsEnabled
                         ? "Announcements On"
                         : "Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var lastAnnouncementSection: some View {
        Section("Last Announcement") {
            if let text = speech.lastSpokenText {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        Section("Settings") {
            Toggle("Announcements", isOn: $connectivity.announcementsEnabled)
        }
    }
}

#Preview {
    WatchContentView()
}
