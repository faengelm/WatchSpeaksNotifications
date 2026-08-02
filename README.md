# Watch Speaks

An iOS + watchOS app that speaks announcements aloud on your Apple Watch. Using the built-in **"Announce on Watch"** Shortcuts action, you can create automations that send any text to your Watch speaker — triggered by messages, calendar events, alarms, location changes, or any other Shortcuts trigger.

## How It Works

1. You create an **automation** in the iPhone Shortcuts app (e.g., "When I receive a message")
2. The automation runs the **"Announce on Watch"** action with the text you want spoken
3. The iPhone sends the text to the Apple Watch via **WatchConnectivity**
4. The Watch speaks it aloud through its built-in speaker with a haptic tap

## Features

### iPhone App
- **Shortcuts Action** — "Announce on Watch" action available in the Shortcuts app for building automations
- **Speech Customization** — Adjust speech rate and pitch to your preference
- **Source Prefix** — Optionally say the source app name before each announcement (e.g., "Calendar: Meeting in 15 minutes")
- **Test Button** — Send a test announcement to verify your Watch speaker
- **Announcement Log** — View recent announcements with delivery status and timestamps

### Apple Watch App
- **Text-to-Speech** — Speaks announcements through the Watch speaker using AVSpeechSynthesizer
- **Haptic Feedback** — Gentle tap when an announcement arrives
- **Queue Management** — Multiple announcements are queued and spoken in order
- **Background Delivery** — Triple-channel delivery (sendMessage + transferUserInfo + applicationContext) for reliability
- **Complication** — Add to your watch face for quick access and improved background performance
- **Settings Sync** — Speech rate and pitch sync from the iPhone app automatically

## Requirements

- **iPhone** running iOS 17.0 or later
- **Apple Watch** running watchOS 10.0 or later

## Setup

### 1. Install & Launch

Install the app on your iPhone. Then open the **Watch** app on your iPhone, scroll to **Watch Speaks**, and tap **Install** to add it to your Apple Watch.

### 2. Test

Tap **"Send Test Announcement"** on the iPhone app to hear your Watch speak. If you hear the announcement, everything is connected.

### 3. Add the Complication (Recommended)

Long-press your watch face, tap **Edit**, and add the **Watch Speaks** complication. This improves background delivery reliability by giving the app more background execution time.

### 4. Set Up Automations

1. Open the **Shortcuts** app on your iPhone
2. Go to **Automations** > **New Automation**
3. Choose a trigger (e.g., "Message", "Calendar", "Alarm", "Arrive at Location")
4. Add the **"Announce on Watch"** action (search for it)
5. Set the text to announce and optionally set the Source App name
6. Enable **Run Immediately**
7. Tap **Done**

Repeat for each event you want announced on your Watch.

> **iOS 27 & later:** The Shortcuts app adds new automation triggers, including **App Notification** — letting you announce any app's notifications on your Watch automatically. Look for additional triggers as Apple expands Shortcuts in future releases.

### Example Automations

| Trigger | Announce Text | Source |
|---------|--------------|--------|
| When I receive a message | "New message received" | Messages |
| When a Calendar event starts | "Meeting starting now" | Calendar |
| When I arrive at Work | "Arrived at work" | Location |
| When an alarm goes off | "Time to wake up" | Alarm |
| When an app sends a notification *(iOS 27+)* | "New notification from App" | App Notification |

## Privacy

- All communication stays between your iPhone and Apple Watch via WatchConnectivity
- No data is transmitted to any external server
- Announcement text is processed locally and spoken on-device
- No health data, location data, or personal information is collected

## License

Copyright &copy; 2026 Technology4Seniors LLC. All rights reserved.
