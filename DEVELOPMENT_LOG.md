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

## 2026-11-11 – Phase 2: core tracking

**Work completed**
- `TimeRange` and local-day helpers; `trackedInRange` duration calculation.
- `TrackingService` with transactional `reconcile()` / `switchTo()`, midnight
  splitting for any number of missed days, and defensive recovery.
- `main.dart` reconciles at startup instead of reading entries directly.
- `tool/test_timezones.sh` timezone matrix.

**Problems and solutions**
- Fixture-created in-memory databases were silently shared (sqflite reuses
  single-instance `:memory:` handles), so a second fixture saw the first's
  activities. `openAppDatabase` now accepts `singleInstance`; tests pass false
  for in-memory databases.
- Checked how Dart resolves non-existent / repeated midnights (Havana) and
  recorded it (D18).

**Testing performed**
- 57 tests pass. DST tests ran in Europe/Berlin, America/Havana,
  Australia/Lord_Howe, Europe/London, America/New_York and were correctly
  skipped in UTC, Asia/Kolkata, Pacific/Kiritimati, Pacific/Pago_Pago.
- Not re-verified on the emulator (it was closed); scheduled for Phase 3.

**Next steps**
- Phase 3: main screen, grid, lifecycle-driven reconcile, display ticker,
  theme/accent settings UI.

## 2026-11-11 – Phase 3: main interface

**Work completed**
- Home screen with header (name, session, today) and a 2×4 grid filling the
  space above the navigation bar; tap switches, long-press edits.
- Activity setup/edit bottom sheet; `ActivityService` for create/update.
- App shell with bottom navigation, lifecycle-driven reconcile.
- Settings: Light/Dark/Black segmented control, five accent swatches, about.

**Problems and solutions**
- On the emulator, the active tile shrank to its text height while empty slots
  filled their cells. Tiles now use `SizedBox.expand`; a widget test asserts
  all eight tiles have equal size.
- Accent swatches were announced twice by TalkBack ("Rose Rose");
  `excludeSemantics` on the labelled wrapper fixes it.
- Theme changes animate (~200 ms); the settings widget test now settles.
- Launcher label was the package name; set to "Time Tracker".

**Testing performed**
- 77 tests pass in all seven timezones of `tool/test_timezones.sh`.
- Emulator (Pixel_10_Pro, debug): first-run grid, setting up slot 2, switching,
  force-stop + relaunch (entries 22:54:59–22:56:14 Free Time, then Gaming open),
  home + return (timer continued from stored start), Black + Rose, Light.

**Next steps**
- Phase 4: activity deletion with history options, history list, entry
  editing/splitting/deleting with overlap resolution.

## 2026-11-11 – Phase 3 revisions from developer feedback

**Requested**
- Grid as 2 rows × 4 columns.
- A dedicated History page: a vertical timeline to scroll back indefinitely,
  activities beside the line, block length proportional to duration.
- Today's total must not lose seconds across switches.
- Timestamp storage spec: UTC epoch microseconds, UTC on read.

**Work completed**
- `lib/util/timestamps.dart` as the single conversion point; schema v2
  migration; `SystemClock` returns UTC; models return UTC.
- Grid constants (`gridRows`, `gridColumns`) and vertical tile layout.
- `HistoryService`, `DayTimeline`, `HistoryScreen`; new History tab.

**Problems and solutions**
- 23 test assertions compared UTC values with local `DateTime`s via `==`;
  added an `isMoment` matcher that compares instants.
- A first list-style day page was replaced mid-way by the timeline design
  after clarification.

**Testing performed**
- 92 tests pass in all seven timezones (new: migration v1→v2, raw storage
  format incl. microsecond precision, seconds accumulation, timeline
  proportions / labels / 24:00 / running entry, history service clipping and
  deleted activities, grid geometry, history scrolling to past days).
- Emulator: existing v1 database migrated to v2 on launch (values ×1000,
  same wall-clock times); 2×4 grid; History timeline shows the 1-minute
  Free Time sliver and the running Gaming block.

**Next steps**
- Developer review, push, then Phase 4.

## 2026-11-11 – Review round 2

**Requested**
- Grid at ~25% of its height; icon-only tiles (pause/play) in activity colour.
- No UI stretching when scrolling past the ends of History.
- Every entry visible on the timeline regardless of length; more zoom.

**Work completed**
- `ActivityTile` rewritten; grid rows fixed at 64 dp, placed at the bottom.
- `scrollBehavior.copyWith(overscroll: false)` on `MaterialApp`.
- `TimelineLayout` (pure, tested) with minimum block height; 4 px/min.
- History day loads share futures and are guarded by a generation counter so
  a load finishing after a tracking change cannot re-insert stale entries
  (found while fixing a lint).
- History toolbar moved out of the overlay (it covered the day header).

**Testing performed**
- 98 tests pass in all seven timezones.
- Emulator: compact grid; six 3–4 s entries all labelled on the timeline;
  mid-drag screenshots at both ends show no stretch.

## 2026-11-11 – Review round 3

**Requested**
- More accents; horizontally scrollable selector with remembered position.
- Remember History's scroll position; update History live, including moving
  the view along with now.

**Work completed**
- `UiStateStore`; 14 accent palettes; scrollable accent row.
- History rewritten around time anchors: `TimelineLayout.timeOf`,
  1-second refresh, follow-now, position keeping, saved/restored anchor,
  in-place refresh on tracking changes.

**Problems and solutions**
- The first position-keeping test passed even with the feature disabled
  (Flutter already keeps position when an off-screen, unlaid-out item
  grows). Added a test where today is partly visible; it exposed two bugs:
  anchors computed with the live clock instead of the built `now`, and
  double correction when the list compensates by itself. Replaced the
  prediction with before/after measurement (D28). Verified the test fails
  with the feature disabled.

**Testing performed**
- 107 tests pass in all seven timezones.
- Emulator: accent row position identical after tab switch and app restart;
  History running entry 9m → 10m and day total 47m → 48m without leaving
  the tab; History position identical after tab switch and restart (stored
  anchor 23:28:25).

## 2026-11-11 – History grid lines

- Added solid hour / dashed half-hour lines (`_GridPainter`) behind the
  timeline entries, using the shared time → y mapping.
- Tests: 48 marks per day alternating, marks only before now for today,
  strictly increasing and in-range on DST days, line positions match layout.
  111 tests pass in all seven timezones.
- Emulator (dark mode): dashed 22:30, solid 23:00, dashed 23:30 exactly at
  the 23:30 entry boundary.

## 2026-11-12 – Phase 4: activity and history management

**Developer rules** for entry editing: change activity; change start/end
with confirmation of overridden entries; delete with fill previous /
following / split evenly. Split-into-two kept from the original spec.

**Work completed**
- Repository helpers (by id, adjacency queries, bounds, reassignment,
  soft delete); `splitAtLocalMidnights` shared with `TrackingService`.
- `ActivityService.delete` with `HistoryChoice`; delete dialog.
- `EntryEditService` with dry-run planning for retime; entry editor sheet and
  dialogs; tap-to-edit on timeline blocks; History refreshes on any edit,
  rename or deletion.

**Problems and solutions**
- Neighbour fill on shrink initially extended into time another entry got
  when an entry was moved elsewhere entirely; now limited to old-minus-new.
- Widget tests found the entry sheet overflowing on short screens; the sheet
  is now scroll-controlled.

**Testing performed**
- 147 tests pass in all seven timezones.
- Emulator: entry sheet, delete options (both neighbours) and start/end
  dialog render correctly in dark mode; live midnight split observed
  (Developing 23:56–24:00 and 00:00–now).

**Next steps**
- Developer review, then Phase 5 (goals).

## 2026-11-12 – Phase 4 review

**Requested**: remove split; an activity may only follow itself at midnight;
replace the day total with an "Info" placeholder; real edits on the emulator
allowed.

**Work completed**: split removed from service, UI and tests;
`mergeSameActivityNeighbours` applied after every edit and after moving a
deleted activity's history; delete offers a single option when both
neighbours match; History day header shows "Info ›".

**Testing performed**
- 151 tests pass in all seven timezones (new: merge after change / delete /
  retime / move-to, no merge across midnight, single delete option, header).
- Emulator, real edits: deleted a 3 s Gaming between two Free Time entries →
  one Free Time 23:26:45–23:26:56; moved a Gaming end to 23:32 → confirmation
  listed "Free Time … removed" and "Gaming … shortened", result one Gaming
  entry 23:27:03–23:32:57.
