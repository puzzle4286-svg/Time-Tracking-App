# Tasks

**Current phase:** Phase 6 – Insights (complete, awaiting review). Next: Phase 7 – Export and backup

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
- [x] First-launch seeding (later changed: Default active, empty grid – D34)
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
- [x] Built-in Default activity; fresh install starts on Default with an
      empty grid; schema v3 (D34)
- [x] No empty time anywhere: fill list without "leave empty" (D35)
- [x] Edits re-split at midnight; header, History refresh after every edit
- [x] Tests: 24 service tests for edits/deletion, 6 widget tests for the flows
- [x] Emulator: real delete (merged Free Time neighbours) and real end change
      with confirmation (removed + shortened, then Gaming merged)

## Phase 5 – Goals
- [x] Goal model + repository (schema v4)
- [x] Period calculation (hours / days / weeks / months, anchored; D9)
- [x] Min / max / both progress, computed from entries only
- [x] Goals page (long-press → Goals) and goal editor (D36)
- [x] Tests: lengths, anchors, before-anchor, transitions, month clamping,
      DST, year-long sweep (every instant in exactly one period, periods
      contiguous), spec examples, sessions crossing boundaries, validation,
      progress after history edits, UI flows
- [x] Emulator: created a daily min 1 h / max 2 h goal; progress matched the
      recorded entries

## Phase 6 – Insights
- [x] Daily timeline with date navigation → delivered as the History tab (D24)
- [x] Global period selector (day/week/month/year/all, ‹ ›) (D38)
- [x] Distribution donut with durations and percentages
- [x] Period comparison bars over full periods; rest of the current period
      counts as Default (Insights only); every activity listed, Default last
- [x] History "Info" opens that day in Insights
- [x] Tests: ranges, navigation, labels, DST day length, distribution,
      comparison (full / truncated / one-sided), UI flows
- [x] Emulator: day and week views with real data

## Phase 7 – Export and backup
- [x] CSV export of time entries (D42)
- [x] JSON export / full backup: raw rows of every table (D40)
- [x] Validated restore with explicit replace confirmation; one transaction,
      app reloads afterwards (D41)
- [x] Settings "Data" section; system save/open dialogs via `file_picker`
- [x] Tests: CSV format/offsets/quoting, backup round trip, schema ↔ backup
      columns, every validation rule, rollback on database rejection,
      tracking after restore, UI flows (export, cancel, replace, invalid file)
- [x] Integration test on the Linux desktop build (real app, database file)
- [x] Manual check of the real system dialogs (Linux portal by the developer;
      Android Storage Access Framework on the emulator)

## Phase 8 – Final testing and polish
- [x] Insights period selector pinned at the top (developer request)
- [x] Full test run (245 tests, seven timezones), analyze, emulator testing
- [x] Lifecycle (background/resume, force-stop/relaunch), persistence,
      Light/Dark themes, navigation checked on the emulator
- [x] Dark launch splash and startup window instead of white (D43)
- [x] Unused `libsqlite3.so` left out of the Android APK (D43)
- [x] Documentation and changelog update
- [x] History: jump to date / restored position load all days in one range
      query and one rebuild (D44)

## After v1 (developer requests, 2026-11-12)
- [x] Activity icons in the editor, shown on tiles (schema v5, D45)
- [x] Active tile highlighted by colour and ring; others muted (D46)
- [x] Goals on the main screen (D47): three bar designs compared, A kept
      (zones, vivid red); only the running activity's goals, under the
      header, goal name instead of activity name
- [x] Older backups (schema v4) upgraded on restore
- [x] Optional Neon look with a switch in Settings (D48)
- [x] Home-screen task switcher widget, one tap per switch (D49)
- [x] Edit sheet clears the navigation bar; grid rearranging
- [x] App icon: Neon (default) and Flat, choosable in Settings (D50); 0.1.1
- [x] Renamed to Lifestring (D51)

## Known issues (accepted, no fix planned)
- Very short entries are stretched to label height on the timeline, so the
  scale is locally non-linear around them (D24).
- The launch splash is always the default dark colour; with Light selected
  it shows dark briefly before the app's first frame (D43).
