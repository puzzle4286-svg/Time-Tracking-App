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
  Future<List<DayEntry>> entriesForDay(DateTime day) async =>
      (await entriesForDays(day, day)).values.single;

  /// Every local day from [first] to [last] (inclusive, either order) with
  /// its entries clipped to that day, oldest first. One query for the whole
  /// range, so loading months of history stays fast.
  Future<Map<DateTime, List<DayEntry>>> entriesForDays(
    DateTime first,
    DateTime last,
  ) async {
    var from = startOfLocalDay(first);
    var lastDay = startOfLocalDay(last);
    if (lastDay.isBefore(from)) (from, lastDay) = (lastDay, from);
    final to = nextLocalMidnight(lastDay);

    final entries = await TimeEntryRepository(_db).overlapping(from, to);
    final activities = await ActivityRepository(_db).allById();

    // Day boundaries are computed once (local-time conversions are slow);
    // entries are then matched to days by integer comparison.
    final days = <TimeRange>[];
    for (var d = from; d.isBefore(to); d = nextLocalMidnight(d)) {
      days.add(localDay(d));
    }
    final dayStarts = [for (final r in days) r.start.microsecondsSinceEpoch];
    final dayEnds = [for (final r in days) r.end.microsecondsSinceEpoch];
    final lists = [for (final _ in days) <DayEntry>[]];

    for (final e in entries) {
      final start = e.start.microsecondsSinceEpoch;
      final end = e.end?.microsecondsSinceEpoch;
      // Last day starting at or before the entry start (0 if earlier).
      var i = _lastAtOrBefore(dayStarts, start);
      // Same overlap rule as the repository query. Usually one day; more
      // only for an entry that crosses midnight.
      for (; i < days.length; i++) {
        if (start >= dayEnds[i]) continue;
        if (end != null && end <= dayStarts[i]) break;
        final range = days[i];
        lists[i].add(
          DayEntry(
            entry: e,
            activity: activities[e.activityId]!,
            start: start < dayStarts[i] ? range.start : e.start,
            end: end == null ? null : (end > dayEnds[i] ? range.end : e.end),
          ),
        );
      }
    }
    final result = {
      for (var i = 0; i < days.length; i++) days[i].start: lists[i],
    };
    return result;
  }
}

/// Index of the last value in ascending [sorted] that is <= [value], or 0.
int _lastAtOrBefore(List<int> sorted, int value) {
  var lo = 0;
  var hi = sorted.length - 1;
  var found = 0;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid] <= value) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}
