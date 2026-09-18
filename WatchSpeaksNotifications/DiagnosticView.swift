import SwiftUI
import WatchConnectivity

struct DiagnosticView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sync = ConnectivityManager.shared
    @State private var copied = false
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text("This page shows raw WCSession state to help diagnose Watch app installation issues. Tap **Copy All** to share.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.blue)
                    }
                }

                Section("WCSession State") {
                    diagRow("activationState")
                    diagRow("isPaired")
                    diagRow("isWatchAppInstalled")
                    diagRow("isReachable")
                    diagRow("isCompanionAppInstalled")
                    diagRow("watchDirectoryURL")
                    diagRow("hasContentPending")
                    diagRow("outstandingUserInfoTransfers")
                    diagRow("outstandingFileTransfers")
                }

                Section("iPhone App") {
                    diagRow("iPhone_version")
                    diagRow("iPhone_build")
                    diagRow("iPhone_bundleID")
                    diagRow("iPhone_iOS")
                    diagRow("notificationPermission")
                }

                Section("Watch App (last sync)") {
                    diagRow("watch_version")
                    diagRow("watch_build")
                }

                Section("Settings") {
                    diagRow("announcementsEnabled")
                    diagRow("prefixSourceName")
                }

                Section {
                    Button {
                        copyDiagnostics()
                    } label: {
                        HStack {
                            Label("Copy All to Clipboard", systemImage: "doc.on.doc")
                            Spacer()
                            if copied {
                                Text("Copied!")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                                    .transition(.opacity)
                            }
                        }
                    }

                    Button {
                        refreshID = UUID()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .id(refreshID)
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func diagRow(_ key: String) -> some View {
        let value = sync.diagnostics[key] ?? "(n/a)"
        let isGood = goodValues(key: key, value: value)

        return HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isGood == nil ? .primary : (isGood! ? .green : .red))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func goodValues(key: String, value: String) -> Bool? {
        switch key {
        case "isPaired": return value == "true"
        case "isWatchAppInstalled": return value == "true"
        case "isReachable": return value == "true" ? true : nil  // not red when unreachable
        case "activationState": return value == "activated"
        case "notificationPermission": return value == "granted"
        default: return nil
        }
    }

    private func copyDiagnostics() {
        let diag = sync.diagnostics
        let sorted = diag.sorted { $0.key < $1.key }
        let lines = sorted.map { "\($0.key): \($0.value)" }
        let text = """
        Watch Speaks Diagnostics
        \(Date().formatted())
        ========================
        \(lines.joined(separator: "\n"))
        """

        UIPasteboard.general.string = text
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { copied = false }
        }
    }
}

#Preview {
    DiagnosticView()
}
