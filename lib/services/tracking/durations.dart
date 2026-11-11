import '../../models/time_entry.dart';
import 'time_range.dart';

/// Total time of [entries] that falls inside [range].
///
/// Open entries are measured up to [now]. Pass [activityId] to count only
/// that activity. Pure function: statistics are always derived from entries,
/// never stored.
Duration trackedInRange(
  Iterable<TimeEntry> entries,
  TimeRange range,
  DateTime now, {
  int? activityId,
}) {
  var total = Duration.zero;
  for (final entry in entries) {
    if (activityId != null && entry.activityId != activityId) continue;
    total += range.overlap(entry.start, entry.end ?? now);
  }
  return total;
}
