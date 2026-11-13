# Changelog

All notable changes are recorded here. Database schema changes are listed
explicitly under **Database**.

## [Unreleased]

## [0.4.1] – 2026-11-13

### Fixed
- Settings → App icon lists the icons as Flat, Neon, Grayscale, the same
  order as the Style setting.
- Activity editor: the Colour and Icon arrows point right when closed and
  down when open.

## [0.4.0] – 2026-11-13

### Added
- Style setting under Appearance: Flat, Neon, Grayscale, each with an
  icon. Replaces the Neon switch; a saved Neon choice carries over.
  Grayscale shows the whole app in shades of grey, activities and the
  home screen widget included, and ignores the accent colour.

- Grayscale launcher icon, next to Neon and Flat in Settings → App icon.

### Changed
- Appearance and Style buttons show the icon above the label.

## [0.3.1] – 2026-11-13

### Fixed
- "Which activity?" closes with a swipe down anywhere on the list, not
  only on the handle above it. A list long enough to scroll scrolls back
  to the top first.
- Lists can be dragged with a mouse (Linux build), like a finger on the
  phone.

## [0.3.0] – 2026-11-13

### Added
- Activity descriptions: an optional "What it covers" text (up to 300
  characters) in the activity editor. Swiping up on the grid opens "Which
  activity?", listing every activity with its description; tapping one
  switches to it, long-pressing opens its editor. A one-time hint explains
  the gesture.
- Debug builds install as a separate app, "Lifestring Dev".

### Changed
- Activity editor: Colour and Icon show one row and open fully when their
  label is tapped (tap again to close). The current choice always stays
  visible.

### Fixed
- Main screen no longer overflows with the phone held sideways: the
  current activity and goals sit on the left, the grid on the right.

### Database
- Schema v6: `activities.description` (nullable text; blank is stored as
  NULL). Older backups are upgraded on restore.

## [0.2.0] – 2026-11-13 and earlier

### Added
- Flutter project scaffold (Android primary, Linux for local checks).
- Strict analyzer and lint configuration.
- Project documentation: README, TASKS, CHANGELOG, DECISIONS, ARCHITECTURE,
  DEVELOPMENT_LOG.

- SQLite storage with versioned migrations (`sqflite`, `path`).
- Activity, TimeEntry and AppSettings models; repositories for each.
- First-launch setup: "Free Time" active at position 1, hidden "Unavailable" activity.
- Light, dark and black themes; accent palettes, persisted.
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

- Delete activities without losing history: keep entries under a new name,
  move them to another activity, or mark them "Unavailable"; a running
  activity hands over to a chosen successor.
- Edit history from the History tab: change activity, change start/end (with
  a confirmation listing every affected entry), or delete and fill the time
  with the previous/following activity or split it between them.
- Back-to-back entries of the same activity are merged after edits (except at
  midnight).

- When an edit frees time, choose what fills it: the neighbouring activity,
  another activity, or nothing.
- Edit confirmations are grouped ("These entries will be removed:", …) and
  show entries in the History style with name and duration.

- Built-in "Default" activity: running on first launch with all eight slots
  empty; offered (last) wherever time must be reassigned.

- Goals: any number per activity, each with a recurring period (N hours,
  days, weeks or months from a chosen local start) and a minimum, a maximum,
  or both; progress bars with percentage, remaining time and exceeded state.

- Insights: period selector (day / week / month / year / all time, step back
  and forward), activity distribution donut with durations and percentages,
  and comparison with the previous period. Periods are always shown in full;
  the rest of the current period counts as Default (Insights only). Every
  activity is listed, Default last.
- History's "Info" opens that day in Insights.

- Settings → Data: export time entries as CSV (readable local times plus
  exact UTC microsecond start, end and duration columns),
  back up all data as one JSON file, and restore a backup after a
  confirmation. Restore checks the whole file first and replaces everything
  in one transaction; a rejected file changes nothing.
- Linux desktop build runs with its own database in
  `~/.local/share/time_tracker` (for development).

- Activity icons: choose one of 32 icons in the activity editor; tiles show
  it (or the name's first letter) instead of pause/play.
- The active tile is shown in full colour with a ring; other tiles
  are muted.
- Neon switch in Settings → Appearance: glowing active tile, timer, goal
  bars, donut, comparison bars, activity dots, entry edges and selected tab;
  inactive tiles as dark outlines.
- Home-screen task switcher widget (Android): the eight tiles; one tap
  switches without opening the app.
- Rearrange grid (long-press an activity → Rearrange grid): drag a tile to
  another slot or tap two slots; occupied slots swap. History is unchanged.
- App icon: the 4 x 2 grid in Neon (default) or Flat; switch in Settings →
  App icon (Android). Replaces the Flutter logo. Version 0.1.1.
- Renamed to **Lifestring** (launcher, Settings, window title, export file
  names). Data, backups and the app ID are unchanged.
- Insights: swipe left / right to change the period; changing it keeps the
  scroll position.
- Version 0.2.0, prepared for F-Droid: GPL-3.0-or-later license, store
  listing, build recipe. **App ID changed** to
  `io.github.puzzle4286svg.lifestring`: installs as a new app; move data with
  a JSON backup.
- Main screen shows the running activity's goals under today's total: one
  bar per goal with green (between targets) and red (over the maximum)
  zones and labelled min / max marks.
- Backups from schema v4 can still be restored after the v5 update.
- Insights: the period selector stays pinned at the top while the charts
  scroll.
- History: jumping to a date far back (or reopening at a saved position)
  loads the days in between with one query instead of one per day.
- Android: dark launch splash and startup window (no white flash); unused
  SQLite library no longer packaged.

### Changed
- Time is never left empty: freed time and deleted entries always go to an
  activity (list of activities, neighbour marked, Default last).

### Fixed
- Entries around midnight could not be edited (the date picker received UTC
  bounds).

### Removed
- Splitting an entry into two of the same activity.
- "N tracked" day total in History headers (replaced by an "Info" placeholder).

### Changed
- Activity grid is now 2 rows × 4 columns of compact buttons filled with the
  activity colour, showing pause (active) or play.
- History timeline zoomed to 240 px per hour; every entry is shown and
  labelled regardless of length; sub-minute durations show seconds.
- Overscroll stretch effect disabled.
- Nine more accent palettes (14 total) in a horizontally scrollable row whose
  position is remembered.
- History updates live every second, follows now when at the bottom, keeps
  the view still otherwise, and remembers its position across tab switches
  and restarts.
- History shows a solid line at every hour and a dashed line at every half
  hour.
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
- Schema v3: `activities.role` marks built-in activities; adds "Default" to
  existing installs.
- Schema v4: `goals` table.
- Schema v5: `activities.icon` (nullable text key of the tile icon).
