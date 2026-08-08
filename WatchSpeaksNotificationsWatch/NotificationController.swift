import SwiftUI
import WatchKit
import UserNotifications
import AVFoundation

/// Custom long-look for Watch Speaks announcements. When the notification is
/// presented (user raised their wrist or tapped it), this speaks the announcement
/// aloud — the long-look is a foreground moment where watchOS permits audio playback.
final class NotificationController: WKUserNotificationHostingController<AnnouncementNotificationView> {
    private let model = AnnouncementNotificationModel()
    private let synthesizer = AVSpeechSynthesizer()

    override var body: AnnouncementNotificationView {
        AnnouncementNotificationView(model: model)
    }

    override func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        model.title = content.title.isEmpty ? "Watch Speaks" : content.title
        model.message = content.body

        // Speak the announcement text (from userInfo or fall back to body)
        let spoken = (content.userInfo["spokenText"] as? String) ?? content.body
        speakNow(spoken)

        // Clear pending speech since the long-look is speaking it
        WatchConnectivityManager.shared.clearPendingSpeech()
    }

    private func speakNow(_ text: String) {
        guard !text.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        session.activate(options: []) { [weak self] activated, _ in
            guard activated, let self else { return }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = SpeechManager.shared.speechRate
            utterance.pitchMultiplier = SpeechManager.shared.speechPitch
            utterance.volume = 1.0
            self.synthesizer.speak(utterance)
        }
    }
}

final class AnnouncementNotificationModel: ObservableObject {
    @Published var title = "Watch Speaks"
    @Published var message = ""
}

struct AnnouncementNotificationView: View {
    @ObservedObject var model: AnnouncementNotificationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(model.title, systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            Text(model.message)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
