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
                    connectivity.speakPendingIfNeeded()
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
                    Text(speech.isSpeaking
                         ? "Tap to cancel"
                         : (connectivity.announcementsEnabled
                            ? "Announcements On"
                            : "Paused"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onTapGesture {
                if speech.isSpeaking {
                    speech.cancelSpeech()
                }
            }

            if let error = speech.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                SpeechManager.shared.speak(
                    "This is a test announcement from Watch Speaks"
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
