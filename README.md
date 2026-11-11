# Time Tracker

An offline-first personal time-tracking app for Android, built with Flutter.

Eight fixed activity buttons. Exactly one activity is always active; tapping
another one switches to it. Tracking is purely timestamp-based, so it survives
the app being closed, killed, or the phone restarting — no background service.

> Status: **Phase 2 – core tracking complete**. See [TASKS.md](TASKS.md).

## Features (planned for v1)

- 8 activity positions in a 2×4 grid; "Free Time" is active on first launch
- Atomic activity switching, automatic midnight splitting, DST-safe
- Activity editing, deletion with history preservation, replacement
- Full historical entry editing (change, split, delete, conflict warnings)
- Flexible goals per activity (any period, minimum and/or maximum)
- Insights: daily timeline, activity distribution, period comparison
- Light, dark and black (OLED) themes; five accent palettes
- CSV / JSON export, full backup and restore

Out of scope for v1: sync, accounts, backend, desktop builds, notifications.

## Technology

- Flutter (stable) / Dart, Material 3
- SQLite via `sqflite`
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

```bash
flutter emulators --launch Pixel_10_Pro   # or connect a device
flutter run
```

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
