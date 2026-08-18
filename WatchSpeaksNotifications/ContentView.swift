import SwiftUI

struct ContentView: View {
    @ObservedObject private var sync = ConnectivityManager.shared

    @State private var showingAbout = false
    @State private var testDelay: TimeInterval = 60
    @State private var testScheduled = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
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
                    .foregroundStyle(sync.isWatchPaired ? .green : .orange)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    if sync.isWatchPaired {
                        Text("Watch Paired")
                            .font(.title2.bold())
                        Text(sync.isWatchReachable
                             ? "Watch app active"
                             : "Watch app in background")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Watch Not Paired")
                            .font(.title2.bold())
                        Text("Pair an Apple Watch to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            Toggle("Enable Announcements", isOn: $sync.announcementsEnabled)
            Toggle("Say Source Name First", isOn: $sync.prefixSourceName)
        } header: {
            Text("Status")
        } footer: {
            if sync.isWatchPaired {
                Text("Announcements are spoken instantly when the Watch app is active. In the background, a notification mirrors to your Watch and speaks during the long-look.")
            } else {
                Text("Pair an Apple Watch to start using Watch Speaks.")
            }
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
            Picker("Fire after", selection: $testDelay) {
                Text("15 seconds").tag(TimeInterval(15))
                Text("30 seconds").tag(TimeInterval(30))
                Text("1 minute").tag(TimeInterval(60))
                Text("2 minutes").tag(TimeInterval(120))
            }

            Button {
                sync.scheduleDelayedTest(seconds: testDelay)
                showScheduled()
            } label: {
                HStack {
                    Label("Send test announcement", systemImage: "speaker.wave.3.fill")
                    Spacer()
                    if testScheduled {
                        Text("Scheduled")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
            }

            if let granted = sync.notificationPermission {
                HStack {
                    Image(systemName: granted ? "bell.badge.fill" : "bell.slash.fill")
                        .foregroundColor(granted ? .green : .red)
                        .font(.caption)
                    Text(granted ? "iPhone Notifications Allowed" : "iPhone Notifications DENIED")
                        .font(.caption)
                        .foregroundColor(granted ? .gray : .red)
                }
            }
            Label {
                Text("You MUST lock your iPhone after tapping Send. Notifications only mirror to your Watch when the iPhone is locked.")
                    .font(.caption)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        } header: {
            Text("Testing")
        } footer: {
            Text("Check: Watch app \u{2192} My Watch \u{2192} Notifications \u{2192} Watch Speaks \u{2192} Mirror iPhone Alerts is ON.\n\nUsing Focus mode? Add Watch Speaks to your Focus filter\u{2019}s allowed apps so notifications are not silenced.")
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

    private func showScheduled() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { testScheduled = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { testScheduled = false }
        }
    }
}

#Preview {
    ContentView()
}
