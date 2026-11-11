import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../tracking/time_range.dart';

/// A time entry as seen on one local day: clipped to that day's boundaries.
class DayEntry {
  const DayEntry({
    required this.entry,
    required this.activity,
    required this.start,
    required this.end,
  });

  final TimeEntry entry;

  /// Always resolvable, even for deleted activities.
  final Activity activity;

  /// Entry start, but not before the day start.
  final DateTime start;

  /// Entry end, but not after the day end. Null while still running.
  final DateTime? end;

  Duration durationAt(DateTime now) {
    final d = (end ?? now).difference(start);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Read access to historical entries. Editing is added in Phase 4.
class HistoryService {
  const HistoryService(this._db);

  final DatabaseExecutor _db;

  /// The local day of the oldest entry (where the history timeline ends).
  Future<DateTime?> firstDay() async {
    final start = await TimeEntryRepository(_db).earliestStart();
    return start == null ? null : startOfLocalDay(start);
  }

  /// Entries overlapping the local calendar day of [day], oldest first.
  Future<List<DayEntry>> entriesForDay(DateTime day) async {
    final range = localDay(day);
    final entries = await TimeEntryRepository(
      _db,
    ).overlapping(range.start, range.end);
    final activities = await ActivityRepository(_db).allById();
    return [
      for (final e in entries)
        DayEntry(
          entry: e,
          activity: activities[e.activityId]!,
          start: e.start.isBefore(range.start) ? range.start : e.start,
          end: e.end == null
              ? null
              : (e.end!.isAfter(range.end) ? range.end : e.end),
        ),
    ];
  }
}
