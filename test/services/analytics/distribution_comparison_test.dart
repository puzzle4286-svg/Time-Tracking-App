import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/analytics/comparison.dart';
import 'package:time_tracker/services/analytics/distribution.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

void main() {
  Activity a(int id, String name, {SystemRole? role, int? position}) =>
      Activity(
        id: id,
        name: name,
        color: 0,
        position: role == null ? position ?? id : null,
        isSystem: role != null,
        createdAt: DateTime(2026),
        deletedAt: null,
        role: role,
      );
  const work = 1, gaming = 2, reading = 5, unavailable = 3, def = 4;
  final activities = {
    work: a(work, 'Work'),
    gaming: a(gaming, 'Gaming'),
    reading: a(reading, 'Reading'),
    unavailable: a(unavailable, 'Unavailable', role: SystemRole.unavailable),
    def: a(def, 'Default', role: SystemRole.defaultActivity),
  };
  const shown = [work, gaming, reading, def];
  var id = 0;
  TimeEntry e(int activity, DateTime s, DateTime? t) =>
      TimeEntry(id: ++id, activityId: activity, start: s, end: t);
  DateTime d(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);

  List<(String, int)> rows(List<ActivityShare> s) => [
    for (final x in s) (x.activity.name, x.duration.inHours),
  ];

  group('distribution', () {
    final today = localDay(d(12, 0));
    final now = d(12, 14);
    final entries = [
      e(work, d(11, 20), d(12, 2)), // 2 h inside today
      e(gaming, d(12, 2), d(12, 8)), // 6 h
      e(unavailable, d(12, 8), d(12, 9)), // 1 h
      e(def, d(12, 9), d(12, 10)), // 1 h
      e(work, d(12, 10), null), // running: 4 h until now
    ];

    test('the rest of today counts as Default; the full day is used', () {
      final s = activityDistribution(
        entries,
        today,
        now,
        activities,
        shown: shown,
        fillActivityId: def,
      );
      expect(rows(s), [
        ('Work', 6), // tie with Gaming: grid order
        ('Gaming', 6),
        ('Unavailable', 1),
        ('Reading', 0), // unused activities are listed
        ('Default', 11), // 1 h recorded + 10 h until midnight, always last
      ]);
      expect(
        s.fold(Duration.zero, (t, x) => t + x.duration),
        const Duration(hours: 24),
      );
      expect(s.fold<double>(0, (t, x) => t + x.fraction), closeTo(1, 1e-9));
    });

    test('past periods are not filled', () {
      final s = activityDistribution(
        entries,
        localDay(d(11, 0)),
        now,
        activities,
        shown: shown,
        fillActivityId: def,
      );
      expect(rows(s), [
        ('Work', 4),
        ('Gaming', 0),
        ('Reading', 0),
        ('Default', 0),
      ]);
    });

    test('a period with no data lists every activity with zero', () {
      final s = activityDistribution(
        const [],
        localDay(d(1, 0)),
        now,
        activities,
        shown: shown,
        fillActivityId: def,
      );
      expect(s.map((x) => x.duration), everyElement(Duration.zero));
      expect(s.map((x) => x.fraction), everyElement(0));
      expect(s.last.activity.name, 'Default');
    });

    test('equal durations keep grid order', () {
      final s = activityDistribution(
        [e(gaming, d(10, 1), d(10, 2)), e(work, d(10, 2), d(10, 3))],
        localDay(d(10, 0)),
        now,
        activities,
        shown: shown,
      );
      expect(s.take(2).map((x) => x.activity.name), ['Work', 'Gaming']);
    });
  });

  group('comparison', () {
    final entries = [
      e(work, d(11, 8), d(11, 12)), // Wed: Work 4 h
      e(gaming, d(11, 12), d(11, 16)), // Wed: Gaming 4 h
      e(work, d(12, 8), d(12, 9)), // Thu: Work 1 h
      e(gaming, d(12, 9), null), // Thu: Gaming running
    ];

    test('full periods; the rest of today is Default; Default last', () {
      final c = comparePeriods(
        entries: entries,
        current: localDay(d(12, 0)),
        previous: localDay(d(11, 0)),
        now: d(12, 10),
        activities: activities,
        shown: shown,
        fillActivityId: def,
      );
      expect(c.previousRange.end, d(12, 0)); // not cut short
      expect(
        [
          for (final r in c.rows)
            (r.activity.name, r.current.inHours, r.previous.inHours),
        ],
        [
          ('Work', 1, 4),
          ('Gaming', 1, 4),
          ('Reading', 0, 0),
          ('Default', 14, 0),
        ],
      );
    });

    test('a previous period without data counts zero for everything', () {
      final c = comparePeriods(
        entries: entries,
        current: localDay(d(11, 0)),
        previous: localDay(d(10, 0)), // before any entry
        now: d(12, 10),
        activities: activities,
        shown: shown,
        fillActivityId: def,
      );
      final work = c.rows.firstWhere((r) => r.activity.name == 'Work');
      expect(work.previous, Duration.zero);
      expect(work.difference, const Duration(hours: 4));
      expect(c.rows.map((r) => r.activity.name), hasLength(4));
    });
  });
}
