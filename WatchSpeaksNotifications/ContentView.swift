import SwiftUI

struct ContentView: View {
    @ObservedObject private var sync = ConnectivityManager.shared

    @State private var showingAbout = false
    @State private var testSent = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                sourcesSection
                speechSection
                testSection
                if !sync.announcementLog.isEmpty {
                    logSection
                }
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
                AboutView()
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundStyle(sync.isWatchReachable ? .green : .orange)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(sync.isWatchReachable ? "Watch Connected" : "Watch Not Reachable")
                        .font(.title2.bold())

                    Text(sync.announcementsEnabled ? "Announcements Active" : "Announcements Paused")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Toggle("Enable Announcements", isOn: $sync.announcementsEnabled)
            Toggle("Say Source Name First", isOn: $sync.prefixSourceName)
        } header: {
            Text("Status")
        } footer: {
            Text("When enabled, selected notifications will be spoken aloud on your Apple Watch.")
        }
    }

    // MARK: - Notification Sources

    private var sourcesSection: some View {
        Section {
            ForEach(sync.sources) { source in
                Toggle(isOn: Binding(
                    get: { source.isEnabled },
                    set: { sync.toggleSource(source.id, enabled: $0) }
                )) {
                    Label(source.name, systemImage: source.icon)
                }
            }
        } header: {
            Text("Notification Sources")
        } footer: {
            Text("Choose which apps\u{2019} notifications are announced. Use the Shortcuts app to create automations that trigger the \u{201C}Announce on Watch\u{201D} action.")
        }
    }

    // MARK: - Speech Settings

    private var speechSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Speech Rate: \(sync.speechRate, specifier: "%.1f")")
                    .font(.subheadline)
                Slider(value: $sync.speechRate, in: 0.1...1.0, step: 0.1)
            }

            VStack(alignment: .leading) {
                Text("Pitch: \(sync.speechPitch, specifier: "%.1f")")
                    .font(.subheadline)
                Slider(value: $sync.speechPitch, in: 0.5...2.0, step: 0.1)
            }
        } header: {
            Text("Speech Settings")
        } footer: {
            Text("Adjust how the Watch speaks announcements. Changes sync automatically.")
        }
    }

    // MARK: - Test

    private var testSection: some View {
        Section {
            Button {
                sync.sendTestAnnouncement()
                showSent()
            } label: {
                HStack {
                    Label("Send Test Announcement", systemImage: "speaker.wave.3.fill")
                    Spacer()
                    if testSent {
                        Text("Sent")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
            }
        } header: {
            Text("Test")
        } footer: {
            Text("Sends a test message to your Apple Watch to be spoken aloud.")
        }
    }

    // MARK: - Announcement Log

    private var logSection: some View {
        Section {
            ForEach(sync.announcementLog.prefix(20)) { entry in
                HStack(spacing: 12) {
                    Image(systemName: entry.delivered ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                        .foregroundStyle(entry.delivered ? .green : .orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text)
                            .font(.subheadline)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            Text(entry.source)
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("\u{00B7}")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button(role: .destructive) {
                sync.clearLog()
            } label: {
                Label("Clear Log", systemImage: "trash")
            }
        } header: {
            Text("Recent Announcements")
        }
    }

    private func showSent() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { testSent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { testSent = false }
        }
    }
}

#Preview {
    ContentView()
}
