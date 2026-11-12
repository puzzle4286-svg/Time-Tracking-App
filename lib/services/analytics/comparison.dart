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
  });

  final TimeRange currentRange;
  final TimeRange previousRange;

  /// Every listed activity, largest first, Default last. Periods without
  /// data simply count zero for every activity.
  final List<ComparisonRow> rows;
}

/// Compares two full, equivalent periods. As in [activityDistribution], the
/// not-yet-elapsed part of a period counts as [fillActivityId] (Default).
PeriodComparison comparePeriods({
  required Iterable<TimeEntry> entries,
  required TimeRange current,
  required TimeRange previous,
  required DateTime now,
  required Map<int, Activity> activities,
  Iterable<int> shown = const [],
  int? fillActivityId,
}) {
  Map<int, Duration> totals(TimeRange r) => {
    for (final s in activityDistribution(
      entries,
      r,
      now,
      activities,
      shown: shown,
      fillActivityId: fillActivityId,
    ))
      s.activity.id: s.duration,
  };
  final a = totals(current);
  final b = totals(previous);
  final rows = [
    for (final id in {...a.keys, ...b.keys})
      ComparisonRow(
        activity: activities[id]!,
        current: a[id] ?? Duration.zero,
        previous: b[id] ?? Duration.zero,
      ),
  ];
  return PeriodComparison(
    currentRange: current,
    previousRange: previous,
    rows: sortDefaultLast(
      rows,
      (r) => r.activity,
      (r) => r.current > r.previous ? r.current : r.previous,
    ),
  );
}
