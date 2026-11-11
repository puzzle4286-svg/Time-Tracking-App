# Tasks

**Current phase:** Phase 1 – Foundation (complete). Next: Phase 2 – Core tracking

A phase is only checked off once its functionality is tested.

## Phase 0 – Inspection and planning
- [x] Inspect repository, Git state, Flutter/Dart, Android tooling
- [x] Create Flutter project (Android + Linux for quick local checks)
- [x] `.gitignore`, strict lint configuration
- [x] Documentation files
- [x] Record technical decisions and product defaults
- [x] Initial commit

## Phase 1 – Foundation
- [x] `Clock` abstraction (system + fake for tests)
- [x] SQLite setup with versioned migrations (`sqflite`; `sqflite_common_ffi` in tests)
- [x] Models: Activity, TimeEntry, settings (Goal model + table deferred to Phase 5 as migration v2)
- [x] Repositories: activities, entries, settings
- [x] First-launch seeding: "Free Time" at position 1 + system "Unavailable" activity
- [x] Initial open entry for Free Time (exactly one active)
- [x] Theme system: light / dark / black, five accent palettes, persisted (UI to switch comes in Phase 3)
- [x] Tests: seeding, initial active state, schema constraints, reopen persistence, settings, themes
- [x] Verified the `one_open_entry` partial unique index rejects a second open entry
- [x] Verified on Android emulator: seeding, force-stop + relaunch keeps the original entry

## Phase 2 – Core tracking
- [ ] `TrackingService.switchTo` in one transaction; no-op on same activity
- [ ] Startup/resume reconciliation incl. multiple missed midnights
- [ ] Local-day boundary helpers (DST-safe)
- [ ] Duration calculations (session, today's total)
- [ ] Tests: switching, repeat select, restart, suspension, midnight, multi-midnight, DST

## Phase 3 – Main interface
- [ ] Current activity header (name, session, today total)
- [ ] 2×4 grid; tap = switch, long-press = edit; empty slots "Tap to set up"
- [ ] UI refresh ticker (display only)
- [ ] Settings: theme mode + accent selection

## Phase 4 – Activity and history management
- [ ] Edit activity (name, color)
- [ ] Delete activity: rename history / replace / mark Unavailable; replacement required if active
- [ ] History list per day; edit activity/start/end; delete; split
- [ ] Overlap detection with explicit resolution (trim neighbours or cancel)
- [ ] Tests for all of the above

## Phase 5 – Goals
- [ ] Goal model + repository
- [ ] Period calculation (hours / days / weeks / months, anchored)
- [ ] Min / max / both progress
- [ ] Goal editor UI
- [ ] Tests: lengths, anchors, transitions, DST, sessions crossing boundaries

## Phase 6 – Insights
- [ ] Daily timeline with date navigation
- [ ] Distribution donut (day/week/month/year/all)
- [ ] Period comparison bars (day/week/month), incomplete periods flagged

## Phase 7 – Export and backup
- [ ] CSV export of time entries
- [ ] JSON export / full backup
- [ ] Validated restore with explicit replace confirmation

## Phase 8 – Final testing and polish
- [ ] Full test run, analyze, device/emulator testing
- [ ] Lifecycle, persistence, theme, navigation checks
- [ ] Documentation and changelog update

## Known issues
- Android launch splash is white while the default theme is dark (cosmetic; Phase 8).
- Temporary Phase 1 home screen only shows the active activity name (replaced in Phase 3).
