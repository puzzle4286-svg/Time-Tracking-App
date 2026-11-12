import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../tracking/time_range.dart';

/// One activity's share of a period.
class ActivityShare {
  const ActivityShare({
    required this.activity,
    required this.duration,
    required this.fraction,
  });

  final Activity activity;
  final Duration duration;

  /// duration / total counted time (0–1); 0 when nothing is counted.
  final double fraction;
}

/// Time per activity inside [range], for Insights.
///
/// - Entries are clipped to the range; the running entry counts up to [now].
/// - The part of the range after [now] (the rest of an unfinished period) is
///   counted as [fillActivityId] (Default), so current periods always show
///   their full length. This is a presentation choice only: nothing is
///   written anywhere.
/// - Every activity in [shown] is listed, even with zero time; activities
///   with time but not in [shown] (e.g. deleted ones) are listed too.
/// - Order: largest first, the fill activity (Default) always last.
List<ActivityShare> activityDistribution(
  Iterable<TimeEntry> entries,
  TimeRange range,
  DateTime now,
  Map<int, Activity> activities, {
  Iterable<int> shown = const [],
  int? fillActivityId,
}) {
  final totals = <int, Duration>{for (final id in shown) id: Duration.zero};
  void add(int id, Duration d) =>
      totals[id] = (totals[id] ?? Duration.zero) + d;

  for (final e in entries) {
    final d = range.overlap(e.start, e.end ?? now);
    if (d > Duration.zero) add(e.activityId, d);
  }
  if (fillActivityId != null && range.end.isAfter(now)) {
    final from = range.start.isAfter(now) ? range.start : now;
    add(fillActivityId, range.end.difference(from));
  }

  final total = totals.values.fold(Duration.zero, (a, b) => a + b);
  final shares = [
    for (final MapEntry(key: id, value: d) in totals.entries)
      ActivityShare(
        activity: activities[id]!,
        duration: d,
        fraction: total == Duration.zero
            ? 0
            : d.inMicroseconds / total.inMicroseconds,
      ),
  ];
  return sortDefaultLast(shares, (s) => s.activity, (s) => s.duration);
}

/// Sorts by [durationOf] (largest first; ties by grid position, then name)
/// with the Default activity always last.
List<T> sortDefaultLast<T>(
  List<T> items,
  Activity Function(T) activityOf,
  Duration Function(T) durationOf,
) {
  int rank(Activity a) => a.isDefault ? 1 : 0;
  return items..sort((x, y) {
    final ax = activityOf(x), ay = activityOf(y);
    final byDefault = rank(ax).compareTo(rank(ay));
    if (byDefault != 0) return byDefault;
    final byTime = durationOf(y).compareTo(durationOf(x));
    if (byTime != 0) return byTime;
    final byPos = (ax.position ?? 99).compareTo(ay.position ?? 99);
    return byPos != 0 ? byPos : ax.name.compareTo(ay.name);
  });
}
