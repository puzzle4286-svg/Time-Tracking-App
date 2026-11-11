# Tasks

**Current phase:** Phase 4 – Activity and history management (complete, awaiting review). Next: Phase 5 – Goals

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
- [x] Theme system: light / dark / black, accent palettes (5, later 14 – D26), persisted
- [x] Tests: seeding, initial active state, schema constraints, reopen persistence, settings, themes
- [x] Verified the `one_open_entry` partial unique index rejects a second open entry
- [x] Verified on Android emulator: seeding, force-stop + relaunch keeps the original entry

## Phase 2 – Core tracking
- [x] `TrackingService.switchTo` in one transaction; no-op on same activity
- [x] Startup reconciliation incl. multiple missed midnights (resume hook wired in Phase 3)
- [x] Local-day boundary helpers (DST-safe), `TimeRange`
- [x] Duration calculations (session, today's total) as pure functions
- [x] Tests: switching, repeat select, restart, suspension, midnight, multi-midnight, DST,
      clock moved back, missing open entry recovery
- [x] Timezone matrix script `tool/test_timezones.sh` (7 zones incl. midnight-DST Havana)

## Phase 3 – Main interface
- [x] Current activity header (name, session, today total)
- [x] 2×4 grid; tap = switch, long-press = edit; empty slots "Tap to set up"
- [x] Activity setup/edit sheet (name, colour); delete comes in Phase 4
- [x] UI refresh ticker (display only); calls `reconcile()` when `dayEnd` is reached
- [x] `AppLifecycleListener`: `reconcile()` on resume
- [x] Bottom navigation: Track / Insights (placeholder) / Settings
- [x] Settings: appearance mode + accent selection, app info
- [x] Widget tests for all of the above
- [x] Verified on emulator: setup, switch, force-stop + relaunch, background + resume,
      light/dark/black, accent change

## Phase 3 revisions (developer feedback, 2026-11-11)
- [x] Grid changed to 2 rows × 4 columns
- [x] History tab: continuous, proportional vertical timeline with jump to date / now
- [x] Timestamps stored as UTC epoch microseconds; schema v2 migration (verified on device)
- [x] Test that seconds from separate sessions add up in totals
- [x] Review round 2: compact icon-only colour tiles (pause/play), no overscroll
      stretch, timeline at 4 px/min with every entry shown and labelled,
      History toolbar no longer overlaps content
- [x] Review round 3: 14 accents in a horizontal, remembered selector;
      History remembers its position (as an instant) across tabs and restarts;
      History updates every second, follows now at the bottom, keeps the view
      still when scrolled into the past
- [x] History grid lines: solid per hour, dashed per half hour

## Phase 4 – Activity and history management
- [x] Edit activity (name, colour)
- [x] Delete activity: keep under new name / move to another / mark Unavailable;
      successor required if running (D29)
- [x] History: tap an entry to change activity, change start/end (with
      confirmation of affected entries), delete with fill options (D30)
- [x] Split removed (developer request); same-activity neighbours merged
      except at midnight (D31); day header "Info" placeholder (D32)
- [x] Freed time: choose neighbour / another activity / empty (D30)
- [x] Confirmation grouped by effect, entry-strip style, precise durations
- [x] Fixed: entries around midnight could not be edited (D33)
- [x] Edits re-split at midnight; header, History refresh after every edit
- [x] Tests: 24 service tests for edits/deletion, 6 widget tests for the flows
- [x] Emulator: real delete (merged Free Time neighbours) and real end change
      with confirmation (removed + shortened, then Gaming merged)

## Phase 5 – Goals
- [ ] Goal model + repository (schema v3)
- [ ] Period calculation (hours / days / weeks / months, anchored)
- [ ] Min / max / both progress
- [ ] Goal editor UI
- [ ] Tests: lengths, anchors, transitions, DST, sessions crossing boundaries

## Phase 6 – Insights
- [x] Daily timeline with date navigation → delivered as the History tab (D24)
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
- Day header "Info ›" has no action yet (D32).
- Grid tiles show no names for now (D23); identify by colour.
- Very short entries are stretched to label height on the timeline, so the
  scale is locally non-linear around them (D24).
- "Jump to date" far into the past loads every day in between (one query per
  day); fine for now, could become a single range query.
- Insights tab is a placeholder until Phase 6.
- Android launch splash is white while the default theme is dark (cosmetic; Phase 8).
