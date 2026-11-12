import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../tracking/time_range.dart';

/// One activity's share of the tracked time in a range.
class ActivityShare {
  const ActivityShare({
    required this.activity,
    required this.duration,
    required this.fraction,
  });

  final Activity activity;
  final Duration duration;

  /// duration / total tracked time (0–1).
  final double fraction;
}

/// Time per activity inside [range], largest first. Entries are clipped to
/// the range; the running entry counts up to [now]. Untracked time is not
/// counted, so fractions add up to 1. "Unavailable" and "Default" appear as
/// their own items.
List<ActivityShare> activityDistribution(
  Iterable<TimeEntry> entries,
  TimeRange range,
  DateTime now,
  Map<int, Activity> activities,
) {
  final totals = <int, Duration>{};
  for (final e in entries) {
    final d = range.overlap(e.start, e.end ?? now);
    if (d > Duration.zero) {
      totals[e.activityId] = (totals[e.activityId] ?? Duration.zero) + d;
    }
  }
  final total = totals.values.fold(Duration.zero, (a, b) => a + b);
  final shares = [
    for (final MapEntry(key: id, value: d) in totals.entries)
      ActivityShare(
        activity: activities[id]!,
        duration: d,
        fraction: d.inMicroseconds / total.inMicroseconds,
      ),
  ]..sort((a, b) => b.duration.compareTo(a.duration));
  return shares;
}
