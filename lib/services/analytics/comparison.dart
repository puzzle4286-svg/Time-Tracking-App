import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../tracking/time_range.dart';
import 'distribution.dart';

/// Time of one activity in two periods.
class ComparisonRow {
  const ComparisonRow({
    required this.activity,
    required this.current,
    required this.previous,
  });

  final Activity activity;
  final Duration current;
  final Duration previous;

  Duration get difference => current - previous;
}

class PeriodComparison {
  const PeriodComparison({
    required this.currentRange,
    required this.previousRange,
    required this.rows,
    required this.truncated,
  });

  /// The ranges actually compared (the previous one may be cut short).
  final TimeRange currentRange;
  final TimeRange previousRange;

  /// Every activity present in either period, largest first.
  final List<ComparisonRow> rows;

  /// True when the current period is still in progress and the previous one
  /// was therefore compared only up to the same point.
  final bool truncated;
}

/// Compares [current] with [previous] (equivalent calendar periods).
///
/// If [current] is in progress at [now], it is counted up to now and the
/// previous period only up to the same elapsed time, so both cover an
/// equivalent span; [PeriodComparison.truncated] says so.
PeriodComparison comparePeriods({
  required Iterable<TimeEntry> entries,
  required TimeRange current,
  required TimeRange previous,
  required DateTime now,
  required Map<int, Activity> activities,
}) {
  final inProgress = current.contains(now);
  final cur = inProgress ? TimeRange(current.start, now) : current;
  final prev = inProgress
      ? TimeRange(
          previous.start,
          _min(previous.start.add(now.difference(current.start)), previous.end),
        )
      : previous;

  final a = {
    for (final s in activityDistribution(entries, cur, now, activities))
      s.activity.id: s,
  };
  final b = {
    for (final s in activityDistribution(entries, prev, now, activities))
      s.activity.id: s,
  };
  final ids = {...a.keys, ...b.keys};
  final rows =
      [
        for (final id in ids)
          ComparisonRow(
            activity: (a[id] ?? b[id])!.activity,
            current: a[id]?.duration ?? Duration.zero,
            previous: b[id]?.duration ?? Duration.zero,
          ),
      ]..sort((x, y) {
        final mx = x.current > x.previous ? x.current : x.previous;
        final my = y.current > y.previous ? y.current : y.previous;
        return my.compareTo(mx);
      });
  return PeriodComparison(
    currentRange: cur,
    previousRange: prev,
    rows: rows,
    truncated: inProgress,
  );
}

DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
