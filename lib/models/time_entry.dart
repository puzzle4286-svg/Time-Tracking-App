import '../util/timestamps.dart';

/// A continuous block of time spent on one activity.
///
/// Instants are stored as UTC epoch microseconds and read back as UTC. An entry with no [end] is
/// the currently active session; the database allows at most one of those.
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.activityId,
    required this.start,
    required this.end,
  });

  final int id;
  final int activityId;
  final DateTime start;

  /// Null while this is the active session.
  final DateTime? end;

  bool get isOpen => end == null;

  /// Length of the entry; an open entry is measured up to [now].
  Duration durationAt(DateTime now) => (end ?? now).difference(start);

  factory TimeEntry.fromRow(Map<String, Object?> row) => TimeEntry(
    id: row['id']! as int,
    activityId: row['activity_id']! as int,
    start: fromStoredTimestamp(row['start_utc']! as int),
    end: fromStoredTimestampOrNull(row['end_utc']),
  );
}
