# Watch Speaks Notifications

An iOS + watchOS app that converts iPhone notifications into spoken announcements on your Apple Watch. When a notification arrives, the Watch speaks it aloud through its built-in speaker — similar to the workout milestone announcements during Apple Watch workouts.

## Features

### iPhone App
- **Notification Source Selection** — Choose which apps' notifications are announced (Messages, Mail, Calendar, Reminders, Phone, and more)
- **Shortcuts Integration** — Provides an "Announce on Watch" action for the Shortcuts app, enabling custom automations
- **Speech Customization** — Adjust speech rate and pitch to your preference
- **Source Prefix** — Optionally say the source app name before each announcement (e.g., "Calendar: Meeting in 15 minutes")
- **Announcement Log** — View recent announcements with timestamps and delivery status
- **Test Mode** — Send a test announcement to verify your Watch speaker

### Apple Watch App
- **Text-to-Speech** — Converts incoming notification text to spoken audio through the Watch speaker
- **Haptic Feedback** — Gentle tap when an announcement arrives
- **Queue Management** — Multiple announcements are queued and spoken in order
- **Extended Runtime** — Uses WKExtendedRuntimeSession to ensure speech completes even when you lower your wrist
- **Settings Sync** — Speech rate and pitch sync from the iPhone app automatically

### Shortcuts Automations

The app provides an **"Announce on Watch"** Shortcuts action. Create automations in the Shortcuts app like:

- "When I receive a message" → Announce on Watch
- "When a Calendar event starts" → Announce on Watch
- "When I arrive at a location" → Announce on Watch
- "When an alarm goes off" → Announce on Watch

## How It Works

1. **Shortcuts Automations** trigger the "Announce on Watch" action when events occur on your iPhone
2. The iPhone app sends the announcement text to the Apple Watch via **WatchConnectivity**
3. The Watch app uses **AVSpeechSynthesizer** to speak the text through the Watch speaker
4. A haptic tap accompanies each announcement so you know one is coming

> **Note:** iOS sandboxing prevents third-party apps from directly intercepting other apps' notifications. This app bridges that gap using Apple's Shortcuts automations framework, giving you flexible control over which events trigger Watch announcements.

## Requirements

- **iPhone** running iOS 17.0 or later
- **Apple Watch** running watchOS 10.0 or later

## Setup

### 1. Install & Launch

Install the app on your iPhone. The Watch app installs automatically on your paired Apple Watch.

### 2. Configure Sources

Open the iPhone app and toggle which notification sources you want announced. This filters announcements when they arrive via Shortcuts.

### 3. Test

Tap **"Send Test Announcement"** to hear your Watch speak. If you hear the announcement, everything is connected.

### 4. Set Up Automations

1. Open the **Shortcuts** app on your iPhone
2. Go to **Automations** → **New Automation**
3. Choose a trigger (e.g., "Message", "Calendar", "Alarm")
4. Add the **"Announce on Watch"** action (search for it)
5. Set the text to announce
6. Enable **Run Immediately**
7. Tap **Done**

Repeat for each app or event you want announced on your Watch.

### 5. Verify Watch Connectivity

Open the iPhone app and tap the gear icon → **About**. If the Watch App version appears, the Watch is communicating successfully. If it shows "—", open the Watch app to trigger a sync.

## Privacy

- All communication stays between your iPhone and Apple Watch via WatchConnectivity
- No data is transmitted to any external server
- Notification content is processed locally and spoken on-device
- No health data, location data, or personal information is collected

## License

Copyright &copy; 2026 Technology4Seniors LLC. All rights reserved.
