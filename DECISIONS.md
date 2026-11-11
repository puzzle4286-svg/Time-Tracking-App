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

## D4 – Timestamps: UTC epoch milliseconds
All instants are stored as integer UTC milliseconds. This is unambiguous and
unaffected by device timezone changes. Local time is only used to *interpret*
instants: day boundaries, goal periods and display.

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

## D12 – Models expose local `DateTime`s
Rows store UTC milliseconds; models convert with `fromMillisecondsSinceEpoch`,
which yields a local `DateTime` for the same instant. Code compares instants,
not representations (`==` on `DateTime` also compares the UTC flag).

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
