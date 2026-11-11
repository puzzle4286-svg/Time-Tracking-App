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

## D9 – Goal periods: unit + length + local anchor
A goal period is `length × unit` (`hour`, `day`, `week`, `month`) anchored at a
local wall-clock datetime. Hours are fixed durations from the anchor instant;
days/weeks/months step in the local calendar (DST-safe, month-end clamped).
This covers "24 h from 00:00", "7 days from Monday 00:00", "month from the 1st"
and arbitrary periods without hardcoding daily/weekly/monthly.

## D10 – Product defaults (confirmed with developer, 2026-11-11)
- Positions 2–8 start empty ("Tap to set up"); empty slots cannot be active.
- "Unavailable" time is shown in Insights as its own grey item.
- Live session shown as `1:42:15`; totals shown as `2h 42m`.
- Overlapping history edits are never applied silently: the user chooses to
  trim neighbouring entries or cancel.

## D11 – Dependencies added only when their phase needs them
Added in Phase 1: `sqflite` 2.4, `path` 1.9, dev `sqflite_common_ffi` 2.4. Planned, `fl_chart` (Phase 6), `share_plus`,
`file_picker` (Phase 7). Each addition is recorded here.

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
  "name  start – end · duration" (two lines when the block is tall enough).
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
  chooses per side what fills exactly the freed part of the old range: the
  adjacent neighbour's activity, another activity, or nothing. The neighbour
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
  activity". "Leave empty" appears only when no neighbour is adjacent (and
  never for the running entry).
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
