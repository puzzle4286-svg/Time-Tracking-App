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

### Database
- Schema v1: `activities`, `time_entries`, `settings`. Constraints: at most one
  open entry, non-negative durations, unique live positions 1–8, foreign keys
  with `ON DELETE RESTRICT`.
