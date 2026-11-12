import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/analytics/comparison.dart';
import 'package:time_tracker/services/analytics/distribution.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

void main() {
  Activity a(int id, String name, {SystemRole? role}) => Activity(
    id: id,
    name: name,
    color: 0,
    position: role == null ? id : null,
    isSystem: role != null,
    createdAt: DateTime(2026),
    deletedAt: null,
    role: role,
  );
  final activities = {
    1: a(1, 'Work'),
    2: a(2, 'Gaming'),
    3: a(3, 'Unavailable', role: SystemRole.unavailable),
    4: a(4, 'Default', role: SystemRole.defaultActivity),
  };
  var id = 0;
  TimeEntry e(int activity, DateTime s, DateTime? t) =>
      TimeEntry(id: ++id, activityId: activity, start: s, end: t);
  DateTime d(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);

  group('distribution', () {
    final day = localDay(d(12, 0));
    final now = d(12, 18);
    final entries = [
      e(1, d(11, 20), d(12, 2)), // 2 h inside the day
      e(2, d(12, 2), d(12, 8)), // 6 h
      e(3, d(12, 8), d(12, 9)), // 1 h Unavailable
      e(4, d(12, 9), d(12, 10)), // 1 h Default
      e(1, d(12, 10), null), // running: 8 h until now
    ];

    test('per activity, largest first, clipped to the range', () {
      final shares = activityDistribution(entries, day, now, activities);
      expect(shares.map((s) => (s.activity.name, s.duration.inHours)), [
        ('Work', 10),
        ('Gaming', 6),
        ('Unavailable', 1),
        ('Default', 1),
      ]);
    });

    test('fractions are shares of tracked time and add up to 1', () {
      final shares = activityDistribution(entries, day, now, activities);
      expect(shares.first.fraction, closeTo(10 / 18, 1e-9));
      expect(
        shares.fold<double>(0, (s, x) => s + x.fraction),
        closeTo(1, 1e-9),
      );
    });

    test('gaps are not counted as tracked time', () {
      final gappy = [e(1, d(12, 1), d(12, 2)), e(2, d(12, 5), d(12, 6))];
      final shares = activityDistribution(gappy, day, now, activities);
      expect(shares.map((s) => s.fraction), [0.5, 0.5]);
    });

    test('empty range', () {
      expect(activityDistribution(const [], day, now, activities), isEmpty);
    });
  });

  group('comparison', () {
    final entries = [
      // Wednesday 11 Nov
      e(1, d(11, 8), d(11, 12)), // Work 4 h (2 h before 10:00)
      e(2, d(11, 12), d(11, 16)), // Gaming 4 h
      // Thursday 12 Nov
      e(1, d(12, 8), d(12, 9)), // Work 1 h
      e(2, d(12, 9), null), // Gaming running
    ];

    test('a finished period is compared in full', () {
      final c = comparePeriods(
        entries: entries,
        current: localDay(d(11, 0)),
        previous: localDay(d(10, 0)),
        now: d(12, 10),
        activities: activities,
      );
      expect(c.truncated, isFalse);
      expect(c.rows.map((r) => (r.activity.name, r.current, r.previous)), [
        ('Work', const Duration(hours: 4), Duration.zero),
        ('Gaming', const Duration(hours: 4), Duration.zero),
      ]);
    });

    test('an unfinished period compares to the same point of the previous', () {
      final c = comparePeriods(
        entries: entries,
        current: localDay(d(12, 0)),
        previous: localDay(d(11, 0)),
        now: d(12, 10),
        activities: activities,
      );
      expect(c.truncated, isTrue);
      expect(c.previousRange.end, d(11, 10));
      final work = c.rows.firstWhere((r) => r.activity.name == 'Work');
      final gaming = c.rows.firstWhere((r) => r.activity.name == 'Gaming');
      expect(
        (work.current, work.previous),
        (const Duration(hours: 1), const Duration(hours: 2)),
      );
      expect(
        (gaming.current, gaming.previous),
        (const Duration(hours: 1), Duration.zero),
      );
      expect(work.difference, const Duration(hours: -1));
    });

    test('activities present in only one period are listed with zero', () {
      final c = comparePeriods(
        entries: [e(1, d(11, 8), d(11, 9))],
        current: localDay(d(12, 0)),
        previous: localDay(d(11, 0)),
        now: d(13, 0),
        activities: activities,
      );
      expect(c.rows.single.current, Duration.zero);
      expect(c.rows.single.previous, const Duration(hours: 1));
    });
  });
}
