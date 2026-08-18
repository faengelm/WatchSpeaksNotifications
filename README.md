# Watch Speaks

An iOS + watchOS app that speaks announcements aloud on your Apple Watch. Using the built-in **"Announce on Watch"** Shortcuts action, you can create automations that send any text to your Watch speaker — triggered by messages, calendar events, alarms, location changes, or any other Shortcuts trigger.

## How It Works

1. You create an **automation** in the iPhone Shortcuts app (e.g., "When I receive a message")
2. The automation runs the **"Announce on Watch"** action with the text you want spoken
3. The iPhone posts a **time-sensitive notification** with the announcement text
4. watchOS **mirrors** the notification to the Apple Watch
5. The Watch's custom **notification long-look** (WKNotificationScene) speaks the text aloud through AVSpeechSynthesizer

This architecture matches the proven SmartBottleTalk pattern: the iPhone posts all notifications, watchOS mirrors them to the Watch, and the Watch speaks during the notification long-look — a foreground moment where audio playback is permitted.

## Features

### iPhone App
- **Shortcuts Action** — "Announce on Watch" action available in the Shortcuts app for building automations
- **Speech Customization** — Adjust speech rate and pitch to your preference
- **Source Prefix** — Optionally say the source app name before each announcement (e.g., "Calendar: Meeting in 15 minutes")
- **Delayed Test** — Schedule a test announcement with a configurable delay so you can lock your iPhone first
- **Announcement Log** — View recent announcements with delivery status and timestamps
- **Notification Permission Status** — Shows whether iPhone notifications are enabled

### Apple Watch App
- **Text-to-Speech** — Speaks announcements through the Watch speaker using AVSpeechSynthesizer
- **Notification Long-Look Speech** — Custom WKNotificationScene speaks announcements when the notification is displayed
- **Haptic Feedback** — Vibration when an announcement arrives in the foreground
- **Queue Management** — Multiple announcements are queued and spoken in order
- **Stuck Speech Recovery** — 10-second timeout with automatic synthesizer recreation, plus tap-to-cancel
- **Settings Sync** — Speech rate and pitch sync from the iPhone app automatically

## Architecture

Watch Speaks uses **iPhone notification mirroring** for reliable background speech:

```
iPhone                          watchOS                        Watch App
  |                               |                              |
  |  Post notification            |                              |
  |  (.timeSensitive,             |                              |
  |   category: ANNOUNCEMENT)     |                              |
  |------------------------------>|                              |
  |                               |  Mirror to Watch             |
  |                               |  (iPhone locked)             |
  |                               |----------------------------->|
  |                               |                              |
  |                               |  WKNotificationScene         |
  |                               |  matches "ANNOUNCEMENT"      |
  |                               |  → NotificationController    |
  |                               |  → didReceive()              |
  |                               |  → SpeechManager.speak()     |
```

**Key design decisions:**
- The Watch uses **zero** `UNUserNotificationCenter` — no permission requests, no category registration, no local notifications
- Background speech relies entirely on iPhone notification mirroring → WKNotificationScene
- Foreground speech uses direct WCSession message delivery + AVSpeechSynthesizer
- The iPhone has the `com.apple.developer.usernotifications.time-sensitive` entitlement for reliable notification delivery

## Requirements

- **iPhone** running iOS 17.0 or later
- **Apple Watch** running watchOS 10.0 or later

## Setup

### 1. Install & Launch

Install the app on your iPhone. The Watch app installs automatically on your paired Apple Watch.

### 2. Allow Notifications

When prompted, allow notifications on your iPhone — this is required for the notification mirroring that enables Watch speech.

### 3. Verify Watch Notification Settings

Open the **Watch** app on your iPhone → **My Watch** → **Notifications** → scroll to **Watch Speaks** → ensure **Mirror iPhone Alerts** is ON.

### 4. Focus Mode (if applicable)

If you use a **Focus mode** (Do Not Disturb, Work, Sleep, etc.), you must add Watch Speaks to the Focus filter's **allowed apps** — otherwise notifications will be silenced and won't mirror to your Watch:

1. Open **Settings** → **Focus** → select your active Focus
2. Under **Allowed Notifications**, tap **Apps**
3. Add **Watch Speaks** to the list

### 5. Test

1. In the iPhone app, pick a delay (e.g., 15 seconds)
2. Tap **"Send test announcement"**
3. **Lock your iPhone immediately** (press the side button) — notifications only mirror to the Watch when the iPhone is locked
4. Wait for the delay — the notification mirrors to your Watch and speaks aloud

> **The iPhone must be locked.** If the iPhone is unlocked, notifications display on the iPhone screen instead of mirroring to the Watch. This is how all iPhone-to-Watch notification mirroring works — it is not specific to Watch Speaks.

### 6. Set Up Automations

1. Open the **Shortcuts** app on your iPhone
2. Go to **Automations** > **New Automation**
3. Choose a trigger (e.g., "Message", "Calendar", "Alarm", "Arrive at Location")
4. Add the **"Announce on Watch"** action (search for it)
5. Set the text to announce and optionally set the Source App name
6. Enable **Run Immediately**
7. Tap **Done**

Repeat for each event you want announced on your Watch.

### Example Automations

| Trigger | Announce Text | Source |
|---------|--------------|--------|
| When I receive a message | "New message received" | Messages |
| When a Calendar event starts | "Meeting starting now" | Calendar |
| When I arrive at Work | "Arrived at work" | Location |
| When an alarm goes off | "Time to wake up" | Alarm |

## Foreground vs. Background

| Watch App State | What Happens |
|----------------|-------------|
| **Foreground** (app is open) | Instant speech + haptic via WCSession |
| **Background** (watch face showing) | iPhone notification mirrors to Watch → long-look speaks the text |
| **iPhone unlocked** | Notification shows on iPhone; mirrors to Watch when iPhone is next locked |

> **Important:** Notification mirroring requires the iPhone to be **locked**. When the iPhone is unlocked, notifications display on the iPhone instead of mirroring to the Watch. For automations triggered while the phone is in your pocket (locked), speech happens automatically.

> **Focus mode:** If a Focus mode is active (Do Not Disturb, Work, Sleep, etc.), add Watch Speaks to the Focus filter's allowed apps. Otherwise, notifications are silenced and won't mirror to the Watch.

## Privacy

- All communication stays between your iPhone and Apple Watch
- No data is transmitted to any external server
- Announcement text is processed locally and spoken on-device
- No health data, location data, or personal information is collected

## License

Copyright &copy; 2026 Technology4Seniors LLC. All rights reserved.
