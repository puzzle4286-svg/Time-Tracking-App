# Development Log

## 2026-11-11 – Phase 0: inspection and planning

**Environment found**
- Empty Git repo on `main`, remote `origin` → GitHub `puzzle4286-svg/Time-Tracking-App` (empty).
- Flutter 3.44.2 stable, Dart 3.12.2. Android SDK 36.1, build-tools 36.1,
  Android Studio JBR 21, AVD `Pixel_10_Pro`. Android licenses accepted by the developer.

**Work completed**
- `flutter create` (org `io.github.puzzle4286svg`, Android + Linux).
- Removed `cupertino_icons` (unused); strict analyzer settings and extra lints.
- `.gitignore` extended for secrets and local exports.
- Minimal app shell (`lib/main.dart`, `lib/app/app.dart`) with a smoke test.
- All documentation files; schema and tracking design in ARCHITECTURE.md;
  decisions D1–D11 including confirmed product defaults.

**Decisions of note**
- No `tracking_state` table: the single open entry is the active state (D7).
- No historical name snapshot column: soft-deleted activity rows keep history
  readable (D8).

**Testing performed**
- `dart format`, `flutter analyze`, `flutter test` (smoke test).

**Next steps**
- Phase 1: clock, database + migrations, models, repositories, seeding, themes.

## 2026-11-11 – Phase 1: foundation

**Work completed**
- Dependencies: `sqflite`, `path`; dev `sqflite_common_ffi`.
- Schema v1 via an ordered migration map; `PRAGMA foreign_keys = ON`;
  downgrades refused with a clear error rather than resetting data.
- Models, repositories, idempotent transactional seeding, `Clock`.
- Theme builder (light/dark/black) and five accent palettes; persisted settings
  via `SettingsController`.
- Temporary home showing the active activity.

**Problems and solutions**
- Seed tests failed comparing a UTC `DateTime` with the local one read back:
  same instant, different representation. Tests now use local times; recorded as D12.

**Testing performed**
- 22 tests (schema constraints incl. single-open-entry index, FK restrict,
  CHECKs; seeding; reopen persistence; settings; themes) pass under the
  system timezone and `TZ=America/New_York`. `flutter analyze` clean.
- Android emulator (Pixel_10_Pro): installed debug APK, launched, force-stopped,
  relaunched; pulled DB shows schema v1, Free Time + Unavailable, one open
  entry with the original start time.

**Next steps**
- Phase 2: `TrackingService` (switching, reconciliation, midnight splitting,
  durations) with DST tests.
