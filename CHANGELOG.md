# Changelog

All notable changes are recorded here. Database schema changes are listed
explicitly under **Database**.

## [Unreleased]

### Added
- Flutter project scaffold (Android primary, Linux for local checks).
- Strict analyzer and lint configuration.
- Project documentation: README, TASKS, CHANGELOG, DECISIONS, ARCHITECTURE,
  DEVELOPMENT_LOG.

- SQLite storage with versioned migrations (`sqflite`, `path`).
- Activity, TimeEntry and AppSettings models; repositories for each.
- First-launch setup: "Free Time" active at position 1, hidden "Unavailable" activity.
- Light, dark and black themes; five accent palettes (Teal, Blue, Violet, Amber, Rose), persisted.
- Injectable `Clock` for time-dependent logic.
- `TrackingService`: atomic activity switching, reconciliation that splits the
  active entry at every missed local midnight, recovery if no entry is open.
- Pure duration helpers (`TimeRange`, `trackedInRange`, local-day boundaries).
- `tool/test_timezones.sh` runs the suite in seven timezones.
- Main screen: current activity, live session (`1:42:15`) and today's total
  (`2h 42m`), 2×4 activity grid with tap-to-switch and long-press editing.
- Activity setup/edit sheet (name, colour) for empty and existing slots.
- Bottom navigation (Track / Insights / Settings); Settings screen with
  appearance mode, accent colour and app info.
- Tracking reconciles on app resume and when midnight passes on screen.

- History tab: continuous vertical timeline back to the first recorded day,
  blocks proportional to duration, labels beside blocks, jump to date / now.

### Changed
- Activity grid is now 2 rows × 4 columns.
- Insights no longer holds the daily timeline; it moved to History.

### Fixed
- Android launcher label now reads "Time Tracker".

### Database
- Schema v1: `activities`, `time_entries`, `settings`. Constraints: at most one
  open entry, non-negative durations, unique live positions 1–8, foreign keys
  with `ON DELETE RESTRICT`.
- Schema v2: all timestamps are now UTC epoch **microseconds** (were
  milliseconds). Migration multiplies existing values by 1000; column names
  unchanged.
