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

/// Merges back-to-back entries of the same activity that overlap
/// [from]–[to] into one. The only place an activity may follow itself is a
/// local midnight (each day keeps its own entries), so pairs meeting exactly
/// at a local midnight are left alone.
Future<void> mergeSameActivityNeighbours(
  TimeEntryRepository entries,
  DateTime from,
  DateTime to,
) async {
  TimeEntry? prev;
  for (final e in await entries.overlapping(from, to)) {
    final p = prev;
    if (p != null &&
        p.end != null &&
        p.activityId == e.activityId &&
        p.end!.isAtSameMomentAs(e.start) &&
        !startOfLocalDay(e.start).isAtSameMomentAs(e.start)) {
      // Delete first: if `e` is open, `p` may only become open afterwards.
      await entries.delete(e.id);
      await entries.setBounds(p.id, p.start, e.end);
      prev = TimeEntry(
        id: p.id,
        activityId: p.activityId,
        start: p.start,
        end: e.end,
      );
      continue;
    }
    prev = e;
  }
}
