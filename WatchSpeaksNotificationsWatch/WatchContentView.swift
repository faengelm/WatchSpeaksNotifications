import SwiftUI

struct WatchContentView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @ObservedObject private var speech = SpeechManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                testSection
                if speech.lastSpokenText != nil {
                    lastAnnouncementSection
                }
                settingsSection
            }
            .navigationTitle("Watch Speaks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                WatchAboutView()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    connectivity.processPendingData()
                }
            }
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

            if let error = speech.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if let lastWake = connectivity.lastBackgroundWake {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Last bg wake: \(lastWake, format: .dateTime.hour().minute().second())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                SpeechManager.shared.speak(
                    "This is a test announcement from Watch Speaks Notifications"
                )
            } label: {
                Label("Test Speech", systemImage: "speaker.wave.3.fill")
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
