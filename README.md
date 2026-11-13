# Lifestring

An offline-first personal time-tracking app for Android, built with Flutter.

Eight fixed activity buttons. Exactly one activity is always active; tapping
another one switches to it. Tracking is purely timestamp-based, so it survives
the app being closed, killed, or the phone restarting — no background service.

> Status: **v0.3.0** – all planned phases complete; signed APKs on GitHub releases. See [TASKS.md](TASKS.md).

## Features (planned for v1)

- 8 activity positions in a 2×4 grid; a built-in "Default" activity runs until you set up your own
- Atomic activity switching, automatic midnight splitting, DST-safe
- Activity editing, deletion with history preservation, replacement
- Full historical entry editing (change, split, delete, conflict warnings)
- Flexible goals per activity (any period, minimum and/or maximum)
- History timeline; Insights with activity distribution and period comparison
- Light, dark and black (OLED) themes; fourteen accent palettes
- CSV / JSON export, full backup and restore

Out of scope for v1: sync, accounts, backend, desktop builds, notifications.

## Install

Download the APK for your phone from the
[latest release](https://github.com/puzzle4286-svg/lifestring/releases/latest)
and open it. Most phones need **`arm64-v8a`**; older 32-bit phones need
`armeabi-v7a`. Android asks you to allow installs from your browser or file
manager the first time.

For automatic updates, add
`https://github.com/puzzle4286-svg/lifestring` in
[Obtainium](https://github.com/ImranR98/Obtainium).

Releases are signed with the developer's key; the certificate's SHA-256
fingerprint is:

```
E6:FE:5A:93:F5:7A:8D:7E:D4:32:91:9A:14:63:AE:9F:85:4E:C8:24:A2:80:5C:4B:74:B2:B8:14:A4:56:45:7A
```

Not on F-Droid yet (D52, D53). F-Droid signs with its own key, so a future
F-Droid build cannot update a GitHub install: switch with a JSON backup.

## Technology

- Flutter (stable) / Dart, Material 3
- SQLite via `sqflite`; charts drawn with Flutter itself (no chart package)
- State: Flutter's built-in `ChangeNotifier` (no state-management package)

See [DECISIONS.md](DECISIONS.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Setup

Requirements: Flutter stable (developed with 3.44.2), Android SDK, an Android
device or emulator.

```bash
flutter doctor            # Android toolchain must be green
flutter pub get
```

## Run

Development uses the Linux desktop build (D39); Android is the target.

```bash
flutter run -d linux
```

```bash
flutter emulators --launch Pixel_10_Pro   # or connect a device
flutter run
```

Debug builds install as a separate app, "Lifestring Dev"
(`io.github.puzzle4286svg.lifestring.dev`), next to a released install (D55).

## Test and check

```bash
dart format .
flutter analyze
flutter test
```

Daylight-saving tests use the local timezone and are skipped if it has no DST.
To run the suite across several timezones (including DST edge cases):

```bash
./tool/test_timezones.sh
```

Integration test on the real app (Linux desktop):

```bash
flutter test integration_test -d linux
```

## Releases

Signed APKs are published on GitHub releases (D53); an F-Droid submission
was declined for now (D52). Store texts live in
`fastlane/metadata/android/en-US/`; the build recipe draft is in
`fdroid/`. For a new version: bump `version` in `pubspec.yaml` and
`appVersion` in `lib/app/app_info.dart`, add
`fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`, commit and tag
`v<version>`, then build and publish:

```bash
flutter build apk --release --split-per-abi
gh release create v<version> build/app/outputs/flutter-apk/app-*-release.apk
```

Signing needs `android/key.properties` and the keystore it points to
(both private, never committed; see D53). Without them release builds use
the debug key.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
