# EmoSphere

> **Share how you feel with the world.** A global mood map built on [Nostr](https://nostr.com).

📱 **Android app (APK)** &nbsp;·&nbsp; 🌐 **Web / PWA (installable on iPhone)**

---

## What is EmoSphere?

EmoSphere lets people around the world share their current emotion — anonymously
and without registration — and watch a live, glowing map of how the planet feels
right now.

- **No accounts.** Your identity is a Nostr key generated on your device.
- **Privacy first.** Location is coarse only (area / city) or off. No emails, no names.
- **Decentralized.** Check-ins are signed Nostr events published to public relays.
  No central server owns your data.

## Emocions / Emotions (8)

| Emotion    | Color   |
|------------|---------|
| Joy        | #FFD93D |
| Calm       | #4ADE80 |
| Love       | #F472B6 |
| Surprise   | #FB923C |
| Sadness    | #60A5FA |
| Anger      | #EF4444 |
| Fear       | #A78BFA |
| Tiredness  | #94A3B8 |

Each check-in has an intensity from 1 to 5 and an optional public note (max 140 chars).

## Platforms

| Platform | How to get it |
|----------|---------------|
| Android  | APK from [Releases](../../releases) |
| iPhone   | Open the web app in Safari → Share → *Add to Home Screen* |
| Web      | https://vojta01.github.io/emosphere/ |

## Features

- 🌍 **World mood map** — heat cells colored by the dominant emotion, brightness by activity
- ✍️ **Check-in** — pick an emotion, set intensity, add a note, choose location precision
- 👥 **Friends** — follow npubs, highlight their emotions on the map and in the feed
- 📜 **History** — your check-ins with simple statistics
- 🌐 **Languages** — Czech & English
- 🌙 **Design** — dark, premium, glass-style UI

## Tech

- [Flutter](https://flutter.dev) (Dart) — one codebase for Android + Web/PWA
- [Nostr](https://nostr.com) — custom event kind `1074` (`#t=emosphere`)
- [flutter_map](https://pub.dev/packages/flutter_map) + OpenStreetMap tiles
- `dart_nostr` for relay communication

## Development

```bash
flutter pub get
flutter run                # run on device/emulator
flutter test               # unit + widget tests
flutter build apk          # Android build
flutter build web --base-href /emosphere/   # PWA build
```

## Status

🚧 **In active development** — the MVP is being built right now.
Check back soon for screenshots and the first release.

## License

TBD.
