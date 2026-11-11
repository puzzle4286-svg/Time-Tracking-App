import 'package:time_tracker/models/time_entry.dart';

import 'tracking_fixture.dart';

/// Monday 2026-11-09, now 15:00:
///   Free Time 09–10 · Gaming 10–12 · Study 12–13 · Free Time 13–now (open)
Future<TrackingFixture> mondayTimeline() async {
  final f = await TrackingFixture.create(DateTime(2026, 11, 9, 9));
  await f.service.reconcile();
  for (final (hour, id) in [(10, f.gaming), (12, f.study), (13, f.freeTime)]) {
    f.clock.set(DateTime(2026, 11, 9, hour));
    await f.service.switchTo(id);
  }
  f.clock.set(DateTime(2026, 11, 9, 15));
  return f;
}

DateTime mon(int hour, [int minute = 0]) => DateTime(2026, 11, 9, hour, minute);

/// Entries as (activityId, local start, local end) for compact assertions.
Future<List<(int, DateTime, DateTime?)>> spans(TrackingFixture f) async => [
  for (final TimeEntry e in await f.entries())
    (e.activityId, e.start.toLocal(), e.end?.toLocal()),
];
