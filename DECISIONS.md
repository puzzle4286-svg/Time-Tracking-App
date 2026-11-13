# Decisions

Short records of important choices. Newest at the bottom.

## D1 – Flutter stable, Android first, Linux enabled for local checks
Android is the only target platform. The Linux desktop platform folder exists
only so the app can be started quickly on the development machine; it is not a
supported product and receives no specific work.

## D2 – State management: built-in `ChangeNotifier`
The app state is small (active entry, eight activities, settings). Flutter's
`ChangeNotifier` + `ListenableBuilder` covers it with zero dependencies.
Alternatives: `provider`, `riverpod`, `bloc` — rejected as unnecessary for this
size. Services are created once in `main.dart` and passed down via
constructors (or a single small `InheritedWidget` if constructor passing gets
noisy).

## D3 – Storage: `sqflite`, raw SQL, hand-written migrations
SQLite is required. `sqflite` is the standard, well-maintained plugin. Tests
use `sqflite_common_ffi` so database logic runs in plain `flutter test`.
Alternatives: `drift` (code generation, more machinery than needed), `isar` /
`hive` (not SQLite). Migrations are numbered steps in `onUpgrade`; the
database is never reset.

## D4 – Timestamps: UTC epoch microseconds (revised 2026-11-11)
All persisted instants are 64-bit integers: microseconds since
1970-01-01T00:00:00Z. Written via `toStoredTimestamp(t)` (=
`t.toUtc().microsecondsSinceEpoch`) and read via `fromStoredTimestamp(v)` (=
`DateTime.fromMicrosecondsSinceEpoch(v, isUtc: true)`), both in
`lib/util/timestamps.dart` — the only place conversion happens. Never stored
as formatted date strings. Local time is only used for display and local
calendar boundaries. Originally milliseconds; schema v2 converted existing
data (×1000). Column names (`start_utc`, …) were kept because
`ALTER TABLE … RENAME COLUMN` is unavailable on older Android SQLite.

## D5 – Day boundaries via Dart's local `DateTime`
A local day is `[DateTime(y, m, d), DateTime(y, m, d + 1))` in the device's
timezone. Dart normalises this correctly across DST, so a day may be 23 or 25
hours. No `timezone` package. DST tests run with `TZ=Europe/Berlin`.

## D6 – Midnight splitting is persisted, statistics still clip
When tracking is reconciled (launch, resume, any tracking operation), an open
entry that started before today's local midnight is closed at each missed
midnight and continued in a new entry per day — so each calendar day has its
own entries, as required. In addition, every statistic clips entries to the
queried range. If the user changes timezone, old entries keep their instants
and are simply bucketed by the current timezone; nothing is rewritten.

## D7 – The open entry is the active state
The active activity is the single time entry with `end_utc IS NULL`. A partial
unique index guarantees at most one open entry; transactions and startup
reconciliation guarantee exactly one. A separate `tracking_state` table was
considered and rejected: it would duplicate the same information and could
disagree with the entries.

## D8 – History names come from the activity row, deletion is soft
Entries reference `activity_id` only; their display name and colour come from
the activity. Deleting an activity sets `deleted_at` and frees its position;
the row stays. The three deletion options map to:
1. **Rename history** – soft-delete and rename the activity row.
2. **Replace** – reassign its entries to another activity, then soft-delete.
3. **Unavailable** – reassign entries to a built-in hidden "Unavailable"
   activity, then soft-delete.

Foreign keys use `ON DELETE RESTRICT`, so entries can never be cascade-deleted.
Consequence: renaming a live activity also renames its history (intended).

## D9 – Goal periods: unit + length + local anchor (implemented Phase 5)
A goal period is `length × unit` (`hour`, `day`, `week`, `month`) anchored at a
local wall-clock start. Hours are fixed durations from the anchor instant;
days/weeks/months step in the local calendar (DST-safe: such periods can be
23/25 h longer or shorter; month starts on the 29th–31st are clamped to the
month's last day). This covers "24 h from 00:00", "7 days from Monday 00:00",
"month from the 1st" and arbitrary periods without hardcoding.
The anchor is stored as calendar fields (`anchor_year/month/day/minute`),
not as a timestamp or string: it is a recurring local rule, so "Monday
00:00" keeps meaning local Monday if the timezone changes. Targets are
stored as durations in microseconds. `goalPeriodAt` (pure) estimates the
period index from the calendar distance and then settles it exactly, which
works for any instant, before or after the anchor.

## D10 – Product defaults (confirmed with developer, 2026-11-11)
- Positions 2–8 start empty ("Tap to set up"); empty slots cannot be active.
- "Unavailable" time is shown in Insights as its own grey item.
- Live session shown as `1:42:15`; totals shown as `2h 42m`.
- Overlapping history edits are never applied silently: the user chooses to
  trim neighbouring entries or cancel.

## D11 – Dependencies added only when their phase needs them
Added in Phase 1: `sqflite` 2.4, `path` 1.9, dev `sqflite_common_ffi` 2.4.
`fl_chart` was not needed (D37). Phase 7: `file_picker` 13.3 (system save /
open dialogs); `share_plus` was not needed, because the save dialog covers
both "keep a copy" and "put it in a synced folder". `sqflite_common_ffi`
became a runtime dependency for the Linux build (D39). Dev: `integration_test`
(Flutter SDK). Home-screen switcher (D49): `home_widget` 0.10 (widget
storage, redraw requests and a background Dart isolate for taps). Each
addition is recorded here.

## D12 – Models expose UTC `DateTime`s (revised 2026-11-11)
Values read from storage are UTC `DateTime`s, and `SystemClock` returns UTC.
Code compares instants (`isAtSameMomentAs`, `difference`), never
representations (`==` on `DateTime` also compares the UTC flag); tests use the
`isMoment` matcher. Local-calendar helpers call `toLocal()` themselves.

## D13 – Repositories wrap a `DatabaseExecutor`
Repositories are tiny objects over a `Database` *or* a `Transaction`, so a
service builds them inside `db.transaction((txn) …)` for atomic operations
without passing transaction handles through every method.

## D14 – Goals table added in Phase 5, not schema v1
The goal design is finalised in Phase 5; adding its table then as migration v2
avoids shipping an unused table and exercises the migration path for real.

## D15 – Default appearance is dark, accent Teal
Defaults until the user chooses otherwise. Stored in `settings` as enum names;
unknown values fall back to defaults instead of failing.

## D16 – Reconciliation runs inside every tracking transaction
`reconcile()` and `switchTo()` both split missed midnights first, in the same
transaction. So even a switch made right after a long gap produces correct
per-day entries without relying on a prior launch or resume hook.

## D17 – Edge cases in switching
- Selecting the active activity: no write at all.
- Zero-length session (two switches at the same instant): the empty entry is
  deleted rather than kept.
- Device clock moved before the session start: no split, the session shows
  0:00, and on the next switch the old entry is closed at its own start
  (zero length, kept) instead of getting a negative duration. Rare; the user
  can fix it via history editing (Phase 4).
- No open entry found (should be impossible): one is opened for the first
  live activity at "now" and a debug message is printed. Missing time is not
  invented.

## D18 – DST semantics
Dart builds local midnights from calendar fields. Verified behaviour:
days can be 23 h or 25 h; where 00:00 does not exist (e.g. Havana) the day
starts at 01:00; where it occurs twice the first one is used. Durations are
always instant differences, so they equal real elapsed time. DST tests find
the local zone's 2026 transition days automatically and are skipped (with a
reason) in zones without DST; `tool/test_timezones.sh` covers both kinds.

## D19 – Bottom navigation: Track / History / Insights / Settings
Material 3 `NavigationBar`, reachable with the thumb. History was added as its
own tab at the developer's request (2026-11-11); history editing (Phase 4)
will be done from the History timeline.

## D20 – Accent vs activity colours
Each activity keeps its own colour (dot in the grid and header; charts later).
The accent palette drives interactive and "active" state: the active tile's
fill and border, the session timer, buttons and navigation. This keeps the two
independent, as required.

## D21 – Setting up an empty slot does not switch to it
Creating an activity is a configuration action; switching remains an explicit
tap, which keeps interactions predictable.

## D22 – App version shown from a constant
`lib/app/app_info.dart` holds the version string instead of adding
`package_info_plus`. It must be kept in sync with `pubspec.yaml`.

## D23 – Grid is 2 rows × 4 columns (developer request, 2026-11-11)
*Tile content superseded by D45/D46: tiles now show the activity's icon (or
its initial) and the active one is highlighted instead of pause/play.*
Positions 1–4 form the top row, 5–8 the bottom row. Revised after review:
tiles are compact (64 dp tall, about a quarter of the earlier grid) and sit at
the bottom of the screen. Each tile is filled with the activity's colour and
shows only a centred icon: pause while that activity runs, play otherwise
("+" on empty slots). Names are not shown on tiles for now (the header shows
the active name; screen readers get the name via a semantics label;
long-press opens the editor). The active tile also gets a contrasting border.

## D24 – History is one continuous, proportional vertical timeline
Replaces the planned Insights "daily timeline" (spec 8.1) with a dedicated
History tab, at the developer's request. Design:
- Reversed `ListView.builder`: now at the bottom, scrolling up goes back one
  local day per item, ending at the first recorded day.
- Scale of 4 px per minute (240 px/hour, about 3 hours per screen): detail
  over overview (revised after review; was 1.5 px/min).
- Every entry is drawn and labelled, however short: blocks have a minimum
  height of one label line (30 px). Time maps to y through
  `TimelineLayout`, a piecewise-linear mapping: gaps and long entries stay
  exactly proportional; only entries shorter than ~8 min are stretched, and
  hour marks follow the same mapping so they stay consistent. Durations under
  a minute show seconds (`40s`).
- Full-width grid lines behind the entries: solid at every hour, dashed at
  every half hour, positioned through the same mapping as the blocks. Marks
  come from calendar fields (`DayTimeline.gridMarks`), so a skipped DST hour
  has no line and a repeated hour is marked once.
- Each entry is a tinted row with a coloured left edge; label is
  "name  start – end · duration" (two lines when the block is tall enough;
  "enough" is measured with the system text scale, since a fixed 48 px
  overflowed with the phone's 1.15x font size).
- Day heights depend on entries, so "Jump to date" loads the days in
  between before computing the offset; "Now" scrolls back to the bottom.
- The Android overscroll stretch is disabled app-wide
  (`scrollBehavior: overscroll: false`).
- Entries are loaded per day on demand and cached; the cache is cleared when
  tracking changes. Insights (Phase 6) keeps distribution and comparison.

## D25 – Totals keep sub-minute precision
Totals are sums of exact timestamp differences (microseconds) and are only
truncated to minutes when formatted, so seconds from separate sessions add up
(3 × 40 s shows as 2m). Nothing stores rounded durations.

## D26 – Fourteen accent palettes in a scrollable row (developer request)
The spec asked for five; the developer asked for more (2026-11-11). Nine were
appended (Indigo, Cyan, Green, Lime, Orange, Red, Pink, Brown, Slate). They are
stored by enum name, so appending never changes saved choices. The selector
is a horizontal list.

## D27 – Persisted UI state in the settings table
Scroll positions live in `settings` under `ui.`-prefixed keys via
`UiStateStore`, loaded once at startup so screens can restore synchronously.
No new table or dependency (`shared_preferences` was not needed). Saved on
scroll end. Keys: `ui.settings.accentScroll` (pixels),
`ui.history.anchor` (`now` or a stored timestamp).

## D28 – History live updates and position anchoring
- The History screen rebuilds every second (display only).
- At the bottom ("now", within 8 px) the view follows the present: today's
  running block grows and earlier content moves up.
- Scrolled away from now, visible content is kept still. This is done by
  measuring a visible day section's on-screen position before and after each
  update and scrolling back any actual shift. Predicting the shift was wrong
  because Flutter's list already compensates size changes of days that are
  not laid out (caught by a test that failed with both approaches until this
  one).
- Anchors for saving/restoring use the `now` the layout was built with, not
  the live clock (otherwise the view drifts ~4 px per second).
- The saved position is the instant at the viewport's bottom edge, so after a
  restart or hours later the same moment is shown in the same place.
- Tracking changes refresh today and yesterday in place, keeping old data
  until the new arrives, so the layout does not jump.

## D29 – Activity deletion
`ActivityService.delete(id, history:, newActiveId:)`. All choices are
validated before anything is written. If the activity is running, the
successor is switched to first (its own atomic transaction, so an activity is
always active), then one transaction applies the history choice and
soft-deletes: `KeepUnderName` renames the kept row, `MoveToActivity`
reassigns entries, `MarkUnavailable` reassigns them to the system activity.
Without entries no choice is needed. The UI defaults to "keep under a new
name" (`<name> (deleted)`), the least surprising option.

## D30 – Editing history entries (developer rules, 2026-11-12)
`EntryEditService`, one transaction per edit, then midnight re-split and a
tracking reconcile so the header, History and future statistics follow.
- **Change activity**: only the entry's activity changes. On the running
  entry this changes what is running without splitting the session.
- **Change start / end**: a dry run (`apply: false`) lists every effect on
  other entries; the UI asks for confirmation if any entry loses time, then
  applies the recomputed plan. Overlapped entries are shortened, split around
  the edited entry, or removed if fully covered. End cannot be in the future;
  the running entry's end cannot be set; an edit may not swallow the running
  entry.
- **Freed time** (revised 2026-11-12): when the entry shrinks, the user
  chooses per side which activity takes exactly the freed part of the old
  range (list of activities, neighbour marked and preselected, Default last;
  never empty – D35). The neighbour
  is not offered when it is the entry's own activity (e.g. the same activity
  continuing past midnight), because filling with it would merge the edit
  away; previously such edits around midnight were silently undone.
- **Confirmation layout**: grouped by effect ("These entries will be
  removed:", "…shortened:", …), sorted by time, each shown as an entry strip
  (History style) with name and duration only; durations in dialogs keep
  seconds below an hour (`1m 37s → 1m 0s`) so changes within a minute are
  visible.
- **Delete**: fill with the previous or following activity, or split the time
  evenly between them. An option is offered only if that neighbour touches
  the entry exactly. Deleting the running entry offers "resume the previous
  activity". With no adjacent neighbour, the user picks the activity that
  takes the time (D35).
- **Split** was briefly offered and then removed at the developer's request
  (2026-11-12): splitting one activity into two of its own makes no sense for
  this app. This deliberately drops the original spec's "split an entry".
- Time pickers have minute precision; an unchanged field keeps its exact
  original timestamp (seconds included).

## D31 – An activity only follows itself at midnight
Back-to-back entries of the same activity are merged after every history
edit (change activity, retime, delete-fill) and after moving a deleted
activity's history (`mergeSameActivityNeighbours`). Pairs that meet exactly
at a local midnight stay separate, because each day keeps its own entries.
Consequence for delete: when both neighbours are the same activity, the three
fill options would give the same result, so only "Fill with <activity>" is
offered.

## D32 – Day header shows "Info" instead of a tracked total
Every day is fully tracked by design, so "N tracked" would read ~24 h. The
header now shows the day label and an "Info ›" placeholder (no action yet),
intended to open that day's Insights later.

## D33 – Date pickers get local bounds
The app clock returns UTC; Flutter's date picker reads calendar fields
directly. After local midnight (while UTC is still the previous date) a UTC
`now` as `lastDate` was "yesterday", the picker asserted and the tap silently
failed — the real reason entries around midnight could not be edited.
`pickDateTime` converts every bound to local time; a widget test reproduces
the failure.

## D34 – Built-in "Default" activity replaces "Free Time" as the start
Developer request (2026-11-12), changing spec 4.1: a fresh install has all
eight grid slots empty and the built-in **Default** activity running. Default
is never on the grid, cannot be renamed or deleted, and cannot be selected
from the grid; it is offered (always last) wherever time must go somewhere:
freed-time fills, deleting an entry with no adjacent neighbour, changing an
entry's activity, the successor of a deleted running activity, and as the
target for a deleted activity's history. Because Default always exists, a
running activity can always be deleted.
Schema v3 adds `activities.role` (`default`, `unavailable`, unique) and
inserts Default for existing installs only; fresh installs get it from
seeding. `Activity.canTakeTime` = grid activity or Default.

## D35 – Time is never left empty
No edit offers or performs "leave empty". Freed time goes to the chosen
activity, otherwise the adjacent neighbour, otherwise Default. Deleting an
entry with no adjacent neighbour asks which activity takes over its time
(implemented as changing that entry's activity). Recovery after a missing
open entry falls back to Default.

## D36 – Goals UI lives behind the activity editor
To keep the main screen uncluttered (spec 5.2), goals are reached via
long-press → "Goals": a page per activity with one card per goal (period,
minimum bar with percentage / "to go" / "reached", maximum bar with used /
left / "over by", paused goals dimmed) and a full-screen editor. Progress is
recomputed from entries on open, on tracking/goal changes and every 15 s.
Goals are only for grid activities (not Default). Goals of a deleted
activity stay in the database untouched (they reference the kept row).

## D37 – Charts without a chart package
The donut is a ~60-line `CustomPainter`; the comparison is horizontal paired
bars built from ordinary widgets (names fit beside bars on a phone, which
vertical bar charts handle poorly). This keeps the dependency count at
`sqflite` + `path` and avoids version churn of a chart library.

## D38 – Insights: one global period selector
Day / Week / Month / Year / All with ‹ › navigation drives both charts
(developer request). Local calendar periods; weeks start on Monday; month
navigation goes via day 1 so 31 March − 1 month is February. "All time" runs
from the first entry to now and has no comparison. Year comparison uses the
same logic as day/week/month (no new analytics feature).
- **Swipe** (developer request, 2026-11-13): a horizontal swipe anywhere on
  Insights does what ‹ › do (left = next, right = previous, page-turn
  direction), with the same limits; at least 64 px or 600 px/s, so vertical
  scrolling and small drags never change the period. While the new period
  loads, the previous results stay on screen, dimmed, under a thin progress
  line, so the list keeps its height and its scroll position (it used to
  jump to the top behind a loading spinner).
- **Full periods, always** (revised after review): the current period is shown
  in full; its not-yet-elapsed part counts as **Default** in Insights only
  (never written to the database or shown in History). No extra note is
  shown (developer decision, overriding spec 8.3's "make incomplete periods
  clear").
  Time before the first-ever entry is not counted.
- **Every activity is listed** (grid activities and Default, plus any other
  activity with time in the period), even at 0m / 0%. Order: largest first,
  ties by grid position, **Default always last**.
- **Distribution**: shares of the counted time; no total in the donut centre
  (it would almost always read 24 h for a day).
- **Comparison**: selected period vs the previous one, both full. A previous
  period without data counts zero for every activity (difference "+1h 5m").
- Recomputed from entries on every change and every 30 s for periods in
  progress. The selection lives in `AppShell`, so History's "Info" opens that
  day (D32 implemented).

## D39 – Linux desktop build for development (2026-11-12)
Day-to-day development runs the Linux desktop app (`flutter run -d linux`)
instead of the Android emulator. It starts faster and supports hot reload.
Android is still the target, and the emulator is used again if the desktop
build behaves differently. sqflite has no Linux plugin, so `sqflite_common_ffi`
moved from dev to regular dependencies. `main.dart` uses it only on Linux,
with the database at `$XDG_DATA_HOME/time_tracker/time_tracker.db` (default
`~/.local/share/time_tracker`). Android still uses the platform plugin and
`getDatabasesPath()`.

## D40 – Backup format: raw rows of every table (Phase 7)
A backup is one JSON file: `format` (`time-tracker-backup`), `formatVersion`
(envelope, 1), `schemaVersion`, `appVersion`, `createdAtUtcUs` (UTC epoch
microseconds, like every stored instant) and
`tables` with every row of `activities`, `time_entries`, `goals` and
`settings`, using the database's column names and values unchanged (ids, UTC
microseconds, colours as integers). Copying rows exactly makes a restore
lossless and needs no mapping code. `backupTables` lists the columns. A test
compares it with `PRAGMA table_info`, so a future migration fails the tests
until the backup format is updated. "JSON export" and "full backup" are this
same file.
- Only a backup with the current `schemaVersion` and `formatVersion` is
  accepted. A newer one asks the user to update the app. An older one is
  rejected for now; when the schema changes, the restore will run the
  existing migrations on the old rows instead.
- `ui.*` settings (scroll positions) are included. They are harmless and
  keep the backup a plain copy.

## D41 – Restore: validate everything, then replace in one transaction
Restoring never merges. It replaces all data, after a confirmation that
shows the backup's date and contents and says this cannot be undone. Before
the confirmation, the file is checked: JSON, format, versions, exact
columns and types, unique ids, both built-in activities present, every
reference resolves, entries do not overlap, and only the latest entry may be
running. The replace then deletes and inserts in one transaction, so the
database's CHECKs, foreign keys and unique indexes check everything a
second time. Any failure rolls back and the current data stays unchanged.
Afterwards `AppRoot` loads every service again and rebuilds the whole tree
(new `MaterialApp` key), so no screen keeps state from the old data. The
restored running entry continues: reconciliation splits it at any midnights
since the backup, so the time between backup and restore goes to the
activity that was running when the backup was made (consistent with D35).

## D42 – CSV export: readable local times plus exact UTC columns
Columns `activity,start,end,start_utc_us,end_utc_us,duration_us`.
`start` / `end` are local ISO 8601 with their UTC offset
(`2026-11-12T09:30:00+01:00`, seconds) for reading. `start_utc_us` /
`end_utc_us` are the stored instants (microseconds since 1970-01-01 UTC, D4)
and `duration_us` the exact length, so scripts get lossless values that add
up without rounding (revised 2026-11-12 at the developer's request; was
`duration_seconds` with millisecond precision). The running entry has empty
`end` / `end_utc_us`, and its duration runs to the export time. RFC 4180
quoting with CRLF line ends; UTF-8 without a BOM. Entries are already split
at midnight (D6), so each row belongs to one day.

## D43 – Android launch screen and packaging (Phase 8)
- The native launch screen, the Android 12+ splash and the window behind
  Flutter during startup all use `@color/launch_background` (#0E1513, the
  default dark teal background) instead of white. They are shown before the
  app can read the saved appearance from the database, so they always match
  the default theme. Users with Light see a dark launch screen briefly; storing
  the appearance for Android natively was not worth the extra code.
  `values-night` was removed because the launch theme no longer depends on the
  system dark mode.
- `sqflite_common_ffi` (needed for Linux, D39) bundles its own `libsqlite3.so`.
  On Android, sqflite uses the system SQLite through Java and never loads it,
  so `android/app/build.gradle.kts` excludes `**/libsqlite3.so` from the APK
  (about 1.7 MB per ABI). Switching the `sqlite3` package to a system library
  instead was rejected: neither the Linux app nor `flutter test` has SQLite
  loaded already, so that would break both.

## D44 – History loads long ranges in one query (2026-11-12)
Jumping to a date and restoring the saved History position used to load
every day in between separately (two queries and one rebuild per day; about
730 queries for a year). `HistoryService.entriesForDays(first, last)` now
reads the whole range with one overlap query and assigns entries to days in
Dart; the screen loads all missing days with it and rebuilds once.
`entriesForDay` delegates to it, so there is one overlap rule. Day boundaries
are computed once per day and entries are matched by integer comparison,
because local-time conversions dominate the cost (a year of 11 000 entries:
951 ms with per-entry conversions, 142 ms now, on the desktop). The day index
is a calendar-date difference instead of a loop.

Measured with a year of 30 switches a day (10 960 entries, desktop, debug):
Insights day 36 ms, year 85 ms, all 46 ms; backup 157 ms (1.4 MB); restore
0.9 s; CSV export 0.8 s. Phones are a few times slower; every regular screen
stays well under a second. Export and restore are one-off actions.

## D45 – Activity icons (schema v5)
`activities.icon` (TEXT, nullable) stores a key from `activityIcons`
(`lib/models/activity_icons.dart`, 32 general-purpose Material icons: work,
study, reading, fitness, sleep, food, commute, gaming, social, …). A key
rather than a code point keeps the database independent of the icon font and
lets Flutter tree-shake icons (the map is `const`). Unknown keys (from a newer
version) show like "no icon". Without an icon a tile shows the first letter
of the name. Existing activities get no icon in the migration.
Backups now accept older schema versions from `minimumBackupSchemaVersion`
(4) on: `_rowUpgrades[n]` brings a backup's raw rows from version n-1 to n,
mirroring the migration (v5: `icon: null`). This replaces the D40 rule that
only the current version was accepted. Every future migration that touches a
backed-up table needs a row upgrade; the column test fails otherwise.

## D46 – Active tile: full colour and ring; others muted
Pause/play icons were replaced by the activity icon (D45), so the active
state is shown by colour instead: the active tile is filled with its full
colour and has a 3 px ring; inactive tiles are
muted to a 28 % tint of their colour over the surface, with a dimmer icon.
The change animates over 200 ms. Screen readers still get "…, active".
The soft glow it first had was taken out of the default look and moved to
the optional Neon look (D48), at the developer's request (2026-11-12).

## D47 – Goals on the main screen (revised 2026-11-12)
Only the **running activity's** enabled goals are shown, directly under the
header (today's total), read-only; editing stays behind the tile's long
press. Each row: the activity's colour dot, the goal's name if it has one
(the activity name is not repeated, the header shows it), the time tracked
in the current period, one bar, and "targets · until <period end>".
The bar (design A of three compared side by side; the developer chose it)
is linear from 0 to 25 % beyond the largest target. Between minimum and
maximum it is tinted green, beyond the maximum red; the targets have
labelled marks (white minimum, red maximum). The fill uses the activity
colour and turns red past the maximum. The red is a fixed vivid
`goalOverColor` (#FF1744) because the dark theme's error colour is too pale.
The first version (bar spanning the whole period) was dropped: small targets
in long periods sat at the left edge. The rejected designs were equal-width
steps (0 → min → max → over) and a ring gauge with a status sentence.
`GoalService.gridProgress(activityId:)` loads the goals with one entry query;
the list reloads on any change and every 15 s.

## D48 – Optional Neon look (developer request, 2026-11-12)
Settings → Appearance has a **Neon** switch (off by default), stored as the
`neon` setting (`true` / `false`; anything else reads as off). It works with
every appearance mode and accent and changes no colours, only adds glow:
- Active tile: two-layer glow in its colour (tight halo plus wide soft one).
  Inactive tiles become dark (10 % tint over the surface) with a thin outline
  and icon in their colour, like unlit neon tubes.
- Header: the timer glows in the accent colour, the activity dot in its own.
- Goals on the main screen: blurred copy of the fill under the bar; past the
  maximum the red part and the tracked time glow red.
- Insights: blurred copy under each donut segment (all glows drawn before
  the segments, so none covers a neighbour); the current period's
  comparison bars glow, the faded previous ones stay flat.
- Activity dots (header, goals, Insights list, entry editor and pickers):
  one shared `ActivityDot` widget with a strong glow, since a weak one is
  invisible at 10–16 px. Colour and accent swatches are not activity dots
  and stay flat.
- Glow is skipped on bars shorter than they are tall (it would look like a
  blob).
- Entry strips (History, dialogs): the coloured left edge glows.
- Navigation bar: the selected icon glows in the accent colour.
The flag travels as a `ThemeExtension` (`Neon` in
`lib/app/theme/neon.dart`), so widgets ask `Neon.of(context)` and nothing
passes settings around; with it off every helper returns no shadows, so the
default look is unchanged. Glow is strongest on Dark and Black; on Light it
is subtle. Backups need no change: settings rows are copied as they are
(D40).

## D49 – Home-screen task switcher (developer request, 2026-11-12)
A minimal Android home-screen widget: the eight grid tiles in two rows of
four, no title, no background, no time. One tap on a tile switches to that
activity without opening the app; empty slots are left blank. Tiles look
like the app's (icon, or the first letter without one; active tile in full
colour with a ring; others muted; Neon outlines and glow when Neon is on,
with a tighter glow that fits inside the tile image).
- **Size** (tuned on the phone): the widget is 4 x 1 cells (minimum
  250 x 60 dp, so one cell row holds both tile rows) and the tiles fill it.
  Each tile image has the shape of one slot at that size (100 x 52 logical,
  about 71 x 37 dp on the developer's phone, whose launcher cells are about
  75 x 91 dp), with a 4 px gap that also holds the Neon glow; icons are drawn
  larger than in the app because the tiles are smaller. Earlier tries:
  stretched square-ish tiles at 4 x 2 (far too large), fixed 44 x 35 dp
  (too small) and 64 x 51 dp, which needed more than one cell row, so the
  launcher made the frame 4 x 3.
- **Drawing**: Dart paints each tile as a PNG (`SwitcherWidget.paintTile`,
  the same `fillFor` / `foregroundFor` colours as `ActivityTile`). Android
  widgets cannot use the app's icon font, so drawing in Dart is the only way
  to show the same icons. `SwitcherWidgetProvider` (Kotlin) only shows the
  images and attaches the tap links.
- **Switching**: a tap sends `timetracker://switch?id=<id>` to
  `onSwitcherTap`, which home_widget runs in a background Dart isolate. It
  calls the normal `TrackingService.switchTo`, so the switch is the same
  atomic transaction with midnight splitting as in the app; no tracking
  logic exists in Kotlin. The isolate opens its own database connection
  (`singleInstance: false`): sqflite shares single instances per path across
  the whole process, so closing a shared one would close the app's. The app
  reloads tracking state on resume, so it shows the switch when opened.
- **Redrawing**: the app redraws the widget whenever tracking, the
  activities or the settings change (`AppRoot`), and the tap handler redraws
  after each switch. There is no periodic update: the widget shows no time,
  so nothing goes stale.
- The background receiver is not exported, so only the widget's own taps
  can switch activities; other apps cannot.

## D50 – Choosable launcher icon (developer request, 2026-11-12)
Two launcher icons replace the default Flutter logo, both the 4 x 2 grid
with one running tile (green, pause bars) in the activity palette:
**Neon** (default; near-black, outlined tiles, glowing active tile) and
**Flat** (dark slate, muted filled tiles, ringed active tile). Settings →
App icon switches between them (Android only).
- **One source**: `tool/generate_app_icons.py` (Pillow) writes the adaptive
  icon vectors, PNG fallbacks for Android 7 (minSdk 24 predates adaptive
  icons), the Settings previews (`assets/app_icons/`) and a shared
  monochrome layer for Android 13 themed icons. The grid stays inside the
  66 dp safe circle so round masks do not clip it.
- **Switching**: two `activity-alias` launcher entries (`.IconNeon`,
  `.IconFlat`) point at `MainActivity`; `AppIcon.kt` enables one and
  disables the other (`DONT_KILL_APP`), new one first so there is always a
  launcher entry. Android closes every screen opened through an entry when
  it is disabled (`DONT_KILL_APP` only keeps the process), so switching
  right away closed the app. Settings therefore only records the choice
  (SharedPreferences) and `MainActivity.onStop` applies it once the user
  has left the app; not while a picker the app opened is in front (tracked
  via `startActivityForResult` / `onActivityResult`), which would lose the
  backup / restore result. Leaving the app after a change ends its task, so
  it starts fresh from the icon (the process and data are unaffected). Android keeps the choice across restarts and updates, so
  nothing is stored in the database or backups. Alias names are stored by
  Android and must never be renamed.
- Trade-offs: some launchers take a moment to refresh, and a home-screen
  shortcut to the old entry may disappear (re-add it). Updating from 0.1.0
  moves the launcher entry from `MainActivity` to `.IconNeon` once, with the
  same effect.

## D51 – The app is called Lifestring (developer choice, 2026-11-13)
The name is about what tracked time means to the user (one unbroken string
of a life, every moment in exactly one activity) rather than how the app
looks. Shown as the Android launcher label, the window / task title, the
Settings "About" entry, the Linux window title, backup and CSV file names
(`lifestring-backup-…`, `lifestring-entries-…`) and the backup error
message.

Unchanged on purpose, because renaming them would break existing installs
or data: the package / application ID `io.github.puzzle4286svg.time_tracker`
(a new one installs as a separate app without the data), the Dart package
name, the database file `time_tracker.db`, the backup `format` tag
`time-tracker-backup` (older backups must still restore), the widget's
`timetracker://` link scheme, and internal names such as `TimeTrackerApp`.

## D52 – Published on F-Droid; app ID io.github.puzzle4286svg.lifestring (2026-11-13)
- **License**: GPL-3.0-or-later (`LICENSE`), the usual choice on F-Droid:
  anyone may reuse the code, and versions they distribute stay open source.
- **App ID** changed from `io.github.puzzle4286svg.time_tracker` to
  `io.github.puzzle4286svg.lifestring` (Gradle namespace and application
  ID, Kotlin package, widget provider name, Linux application ID and binary
  name), before the first public release, because it can never change
  afterwards. F-Droid signs with its own key, so the F-Droid build could not
  update the existing install anyway. The new ID installs as a separate app:
  move data with a JSON backup (the format tag is unchanged, D51). Still
  `time_tracker`: the Dart package name, the database file, the method
  channel name and the Linux data folder (internal, or would lose data).
- **Build recipe** (`fdroid/io.github.puzzle4286svg.lifestring.yml`, the
  draft for fdroiddata): Flutter 3.44.2 from F-Droid's srclib, pub cache
  inside the build directory, release signing line removed (F-Droid signs).
  `package:sqlite3` (needed only for the Linux build, D39) would download a
  prebuilt SQLite in its build hook even for Android, where it is excluded
  from the APK anyway (D43). The recipe sets its `source: system` user
  define, so nothing is downloaded or bundled; Android reads SQLite through
  sqflite. The repo keeps the default so the Linux build and `flutter test`
  keep working. Checked by building a clean copy with the recipe's
  commands: unsigned APK, no SQLite library, only Flutter's libraries and
  `libdartjni` (compiled from source by package:jni).
- **Store listing** in `fastlane/metadata/android/en-US/` (title,
  descriptions, per-versionCode changelogs, 512 px icon from
  `tool/generate_app_icons.py`). New versions: bump `version` in
  pubspec.yaml and `appVersion`, add `changelogs/<versionCode>.txt`, tag
  `v<version>`; F-Droid's update check reads the tags.
- Version 0.2.0 (versionCode 3) is the first F-Droid release.
- Per fdroiddata's checklist: `commit` is the full hash of the release tag,
  and there is one build per ABI (`--split-per-abi`, version codes
  1000 × ABI + build number via `VercodeOperation`; arm64 is 19.6 MB instead
  of 54.8 MB universal). **Reproducible builds are not enabled**: there is
  no release signing key and no signed APKs on GitHub releases, and Flutter
  builds are not yet byte-for-byte reproducible here. F-Droid signs with its
  own key, which cannot be switched to the developer's key later.

## D53 – Signed APKs on GitHub releases (2026-11-13)
- F-Droid closed the merge request: the app must be maintained for more
  than 3 months, and reviewers saw no unique features. Resubmit from about
  2027-02-13 with a release history and a clearer listing.
- Until then releases go to GitHub with APKs signed by a release key
  (RSA 4096, PKCS12, alias `lifestring`, valid 100 years; certificate
  SHA-256 `E6:FE:5A:93:…:45:7A`, full value in the README). Installable
  directly or through Obtainium, which follows the releases.
- The keystore and `android/key.properties` live outside git (both are
  ignored); the master copy is in `~/.android-keys/lifestring/`. **Losing
  the key means no update can ever reach existing installs**, so it must be
  backed up off this machine.
- `build.gradle.kts` signs with the release key when `key.properties`
  exists, else with the debug key. The debug line is kept verbatim so the
  F-Droid recipe's `sed` still deletes it and F-Droid builds stay unsigned
  (checked with a clean copy: unsigned APK).
- Only per-ABI APKs are published (version codes 1000/2000/4000 + build).
  A universal APK would have the bare build number, so switching between
  the two would look like a downgrade.

## D54 – Activity descriptions and "Which activity?" (2026-11-13)
- Each grid activity can have a description of what it covers (optional,
  at most 300 characters, trimmed; blank is stored as NULL). Schema v6
  adds `activities.description`; backups from v4/v5 restore with no
  descriptions.
- Edited in the activity editor, right under the name, so it is written
  once when the activity is set up.
- Used through "Which activity?": swiping up on the grid opens a sheet
  with every grid activity, its icon and its description (activities
  without one say how to add it). Tapping one switches to it, so looking
  something up and switching is one step.
- A gesture instead of a button, to keep the main screen as clean as
  before (a "Which activity?" button above the grid was tried and dropped).
  Taps and long presses on tiles are unchanged; in the list, tap switches
  and long press opens the editor, like on the tiles. Discoverability: the first
  saved description shows a one-time hint (`ui.home.guideHintShown`), and
  the editor's helper text names the gesture.
- Default and Unavailable have no description: they are built in and not
  editable.

## D55 – Debug builds install as "Lifestring Dev" (2026-11-13)
- Debug builds use the app ID `io.github.puzzle4286svg.lifestring.dev` and
  the label "Lifestring Dev", so they install next to the released app
  (GitHub/Obtainium) instead of replacing it, with their own database. Move
  data over with a JSON backup when needed.
- `AppIcon.kt` builds the launcher alias names from the Kotlin package, not
  from `packageName`, because the aliases keep their class names while the
  app ID changes.
- Release and F-Droid builds are unchanged (no suffix, label "Lifestring").

## D56 – Main screen in landscape (2026-11-13)
- Held sideways, header, goals and the two grid rows do not fit stacked
  (overflow by about 20 px on a 900 × 408 dp phone). In landscape the main
  screen puts the header and goals on the left and the grid on the right,
  at the bottom within thumb reach. The header scales down rather than
  overflow on very short screens, and the grid scrolls if it must.
- `test/screens/landscape_test.dart` opens every screen and sheet
  (main screen, activity editor, set-up, "Which activity?", Goals, goal
  editor, Rearrange grid, History with entry actions and editor, Insights,
  Settings) at that size with system bars and a cutout, and fails on any
  overflow. Only the main screen overflowed.

## D57 – Collapsible Colour and Icon in the activity editor (2026-11-13)
- Both show only their first row until their label is tapped; tapping again
  closes them. Closed by default every time the editor opens, so the
  description field, colours and Save fit without scrolling.
- The row length follows the sheet width. If the current choice is not in
  the first row, it takes that row's last place, so the current colour or
  icon is always visible when closed.

