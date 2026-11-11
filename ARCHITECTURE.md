# Architecture

Status: Phases 1–4 implemented (storage, seeding, theme, tracking, main UI,
history timeline, activity deletion, history editing).
Goals and analytics sections describe the planned design.

## Layers

```
screens/ & widgets/      UI only; read state, call services
        │
services/                business logic, pure where possible
  tracking/              switching, reconciliation, durations
  goals/                 period + progress calculation
  analytics/             timeline, distribution, comparison
  export/                CSV, JSON backup, restore validation
        │
repositories/            SQL for one table/aggregate each
        │
database/                open, schema, migrations
```

Plus `models/` (plain immutable data classes), `app/` (root widget, theme), and
`util/clock.dart`. Folders are created only when they get code.

Rules:
- Widgets never run SQL; repositories contain no business rules.
- Calculations (durations, goals, analytics) are pure functions over entries
  and a time range, so they are testable without a database.
- All time comes from an injected `Clock`; the UI ticker only triggers repaints.

## Data flow

1. `main.dart` opens the database, creates repositories and services, and runs
   tracking reconciliation before the first frame.
2. `AppShell`'s `AppLifecycleListener` re-runs reconciliation on resume; the
   header's ticker re-runs it when `ActiveSession.dayEnd` is reached.
3. A tap calls `TrackingService.switchTo(activityId)` → one transaction →
   `TrackingService` notifies listeners → UI rebuilds.
4. A one-second display ticker recomputes `now − start` for the header only.

## Tracking logic

- **Active state:** the single entry with `end_utc IS NULL` (see D7).
- **Switch(A → B) transaction:** reconcile; if open entry is B, do nothing;
  else set `end_utc = now` on the open entry and insert `(B, start = now)`.
- **Reconcile(now):** while the open entry's start is before the local
  midnight `m` of `now`'s day: close it at the first midnight after its start
  and insert a continuation for the same activity starting at that midnight.
  Repeated for every missed midnight. If no open entry exists (should never
  happen), open one for Free Time / first live activity and log it.
- **Durations:** `session = now − open.start`; `todayTotal(activity) =` sum of
  that activity's entries clipped to today's local range, open entry using `now`.
  `ActiveSession` caches the closed part once per change, so the per-second UI
  refresh does no database work; `ActiveSession.dayEnd` tells the UI when to
  call `reconcile()` because a day ended while it was visible.
- Edge cases (same activity, zero length, clock moved back, missing open
  entry): see DECISIONS D17.

## Implemented files

| Path | Purpose |
|---|---|
| `lib/main.dart` | Opens DB, seeds, loads settings, runs app |
| `lib/app/app.dart` | Root `MaterialApp`, rebuilds on settings change |
| `lib/app/settings_controller.dart` | `ChangeNotifier` for settings; persists before notifying |
| `lib/app/theme/app_theme.dart` | `buildTheme(mode, accent)` |
| `lib/database/schema.dart` | Ordered migration list; `schemaVersion` |
| `lib/database/app_database.dart` | `openAppDatabase(factory, path)` |
| `lib/database/seed.dart` | `ensureSeeded(db, now)` – idempotent first-launch setup |
| `lib/models/` | `Activity`, `TimeEntry`, `AppSettings`, activity colours |
| `lib/repositories/` | Activity, time-entry and settings SQL |
| `lib/util/clock.dart` | `Clock` / `SystemClock` |
| `lib/services/tracking/time_range.dart` | `TimeRange`, `startOfLocalDay`, `nextLocalMidnight`, `localDay` |
| `lib/services/tracking/durations.dart` | `trackedInRange` – clipped sums over entries |
| `lib/services/tracking/tracking_service.dart` | `TrackingService` (`reconcile`, `switchTo`) and `ActiveSession` snapshot |
| `lib/services/activities/activity_service.dart` | Live grid activities; create / update; name validation |
| `lib/util/duration_format.dart` | `formatClock` (`1:42:15`), `formatTotal` (`2h 42m`) |
| `lib/app/app_shell.dart` | Bottom navigation; reconcile on resume |
| `lib/app/app_info.dart` | App name and version constants |
| `lib/screens/home/` | `HomeScreen`, `CurrentActivityHeader` (1 s display ticker) |
| `lib/screens/settings/settings_screen.dart` | Appearance, accent, about |
| `lib/screens/insights/insights_screen.dart` | Placeholder until Phase 6 |
| `lib/widgets/activities/` | `ActivityTile`, `showActivityEditor` sheet |
| `lib/util/timestamps.dart` | The only storage conversion: UTC epoch µs ⇄ `DateTime` |
| `lib/util/date_format.dart` | `formatTimeOfDay` (`09:05`), `formatDayLabel` (`Today`, `Mon, 9 Nov 2026`) |
| `lib/services/history/history_service.dart` | `entriesForDay` (clipped `DayEntry`s), `firstDay` |
| `lib/screens/history/history_screen.dart` | Continuous reversed timeline, jump to date / now |
| `lib/widgets/timeline/day_timeline.dart` | One day drawn at 4 px/min; every entry labelled |
| `lib/widgets/timeline/timeline_layout.dart` | Pure layout: time ⇄ y (`yOf`, `timeOf`) with minimum block height |
| `lib/services/history/entry_edit_service.dart` | Entry edits: change activity, retime (dry run + apply), delete with fill, split |
| `lib/services/tracking/day_split.dart` | `splitAtLocalMidnights` – shared by tracking and edits |
| `lib/widgets/activities/delete_activity_flow.dart` | Delete dialog: successor + history choice |
| `lib/widgets/entries/entry_editor_sheet.dart` | History entry actions and their dialogs |
| `lib/widgets/common/date_time_picker.dart` | Date + time picking that keeps unchanged seconds |
| `lib/repositories/ui_state_store.dart` | Persisted UI conveniences (scroll positions), `ui.*` keys in `settings` |

## Database (schema v2 implemented; goals planned as v3)

```sql
activities(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,          -- ARGB
  position INTEGER,                -- 1..8 while live, NULL when deleted/system
  is_system INTEGER NOT NULL DEFAULT 0,  -- the hidden "Unavailable" activity
  created_at INTEGER NOT NULL,     -- UTC epoch microseconds
  deleted_at INTEGER               -- UTC epoch microseconds
)
UNIQUE INDEX on activities(position) WHERE deleted_at IS NULL AND position IS NOT NULL

time_entries(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE RESTRICT,
  start_utc INTEGER NOT NULL,      -- UTC epoch microseconds
  end_utc INTEGER,                 -- NULL = currently active
  CHECK (end_utc IS NULL OR end_utc >= start_utc)
)
UNIQUE INDEX one_open_entry ON time_entries((1)) WHERE end_utc IS NULL
INDEX on time_entries(start_utc)

goals(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE RESTRICT,
  name TEXT,
  period_unit TEXT NOT NULL,       -- hour | day | week | month
  period_length INTEGER NOT NULL,  -- >= 1
  anchor_local TEXT NOT NULL,      -- ISO local wall-clock, e.g. 2026-11-09T00:00
  min_ms INTEGER,
  max_ms INTEGER,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
)

settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)   -- theme_mode, accent
```

All timestamps are UTC epoch microseconds (v2 migrated v1 milliseconds ×1000).
`PRAGMA foreign_keys = ON` on every open. Schema version via
`PRAGMA user_version`. No stored statistics — everything is derived from
`time_entries`.
