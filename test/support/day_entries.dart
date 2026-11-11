import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/history/history_service.dart';

/// A [DayEntry] with its own activity, for layout and widget tests.
DayEntry dayEntry(int id, String name, DateTime start, DateTime? end) {
  final activity = Activity(
    id: id,
    name: name,
    color: 0xFF2196F3,
    position: id,
    isSystem: false,
    createdAt: start,
    deletedAt: null,
  );
  return DayEntry(
    entry: TimeEntry(id: id, activityId: id, start: start, end: end),
    activity: activity,
    start: start,
    end: end,
  );
}
