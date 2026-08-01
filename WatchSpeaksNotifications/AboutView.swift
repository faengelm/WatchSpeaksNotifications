import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sync = ConnectivityManager.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "\u{2014}"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "\u{2014}"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Watch Speaks Notifications")
                            .font(.title2.bold())

                        Text("Speak iPhone notifications\naloud on your Apple Watch")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }

                Section("How to Set Up Automations") {
                    instructionRow(1, "Open the Shortcuts app on your iPhone")
                    instructionRow(2, "Tap Automations \u{2192} New Automation")
                    instructionRow(3, "Choose a trigger (e.g. \u{201C}Message\u{201D})")
                    instructionRow(4, "Search for \u{201C}Announce on Watch\u{201D}")
                    instructionRow(5, "Set the text and enable Run Immediately")
                }

                Section("iPhone App") {
                    row("Version", value: appVersion)
                    row("Build", value: buildNumber)
                }

                Section("Watch App") {
                    row("Version", value: sync.watchVersion ?? "\u{2014}")
                    row("Build", value: sync.watchBuild ?? "\u{2014}")
                }

                Section {
                    Text("\u{00A9} 2026 Technology4Seniors LLC.\nAll rights reserved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func instructionRow(_ step: Int, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: "\(step).circle.fill")
                .foregroundStyle(.blue)
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AboutView()
}
