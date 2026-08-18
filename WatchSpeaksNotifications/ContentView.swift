import SwiftUI

struct ContentView: View {
    @ObservedObject private var sync = ConnectivityManager.shared

    @State private var showingAbout = false
    @State private var testSent = false
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
                Text("Announcements are delivered instantly when the Watch app is active, or queued for delivery when it\u{2019}s in the background.")
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
                    Label("Send delayed test", systemImage: "timer")
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
        } header: {
            Text("Testing")
        } footer: {
            Text("Delayed test schedules an iPhone notification — lock your iPhone first so it mirrors to your Watch.\n\nCheck: Watch app → My Watch → Notifications → Watch Speaks → ensure Mirror iPhone Alerts is ON.")
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
