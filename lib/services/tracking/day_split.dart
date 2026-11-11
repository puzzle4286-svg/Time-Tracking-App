import '../../models/time_entry.dart';
import '../../repositories/time_entry_repository.dart';
import 'time_range.dart';

/// Splits [entry] at every local midnight it crosses, so each calendar day
/// has its own entries. A closed entry is split where a midnight lies
/// strictly inside it; an open entry is split at every midnight up to and
/// including [now]. Returns the last piece (the open one, if [entry] was open).
Future<TimeEntry> splitAtLocalMidnights(
  TimeEntryRepository entries,
  TimeEntry entry,
  DateTime now,
) async {
  var current = entry;
  while (true) {
    final boundary = nextLocalMidnight(current.start);
    final end = current.end;
    final crosses = end == null
        ? !boundary.isAfter(now)
        : boundary.isBefore(end);
    if (!crosses) return current;

    if (end == null) {
      await entries.close(current.id, boundary);
    } else {
      await entries.setBounds(current.id, current.start, boundary);
    }
    final id = await entries.insert(
      activityId: current.activityId,
      start: boundary,
      end: end,
    );
    current = TimeEntry(
      id: id,
      activityId: current.activityId,
      start: boundary,
      end: end,
    );
  }
}
