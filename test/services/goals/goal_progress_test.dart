import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/goals/goal_progress.dart';

void main() {
  const study = 7;
  final created = DateTime(2026, 11, 1);

  Goal goal({
    GoalUnit unit = GoalUnit.day,
    int length = 1,
    GoalAnchor? anchor,
    Duration? min,
    Duration? max,
  }) => Goal(
    id: 1,
    activityId: study,
    name: null,
    unit: unit,
    length: length,
    anchor:
        anchor ??
        const GoalAnchor(year: 2026, month: 11, day: 2, minuteOfDay: 0),
    minimum: min,
    maximum: max,
    enabled: true,
    createdAt: created,
  );

  var nextId = 1;
  TimeEntry e(int activity, DateTime start, DateTime? end) =>
      TimeEntry(id: nextId++, activityId: activity, start: start, end: end);

  // Thursday 12 Nov 2026.
  DateTime thu(int h, [int m = 0]) => DateTime(2026, 11, 12, h, m);

  final entries = [
    e(study, DateTime(2026, 11, 11, 22), thu(1)), // crosses midnight
    e(3, thu(1), thu(9)),
    e(study, thu(9), thu(10, 30)),
    e(3, thu(10, 30), thu(14)),
    e(study, thu(14), null), // running
  ];
  final now = thu(15);

  group('spec example: Studying, 24 h from 00:00, min 2 h, max 5 h', () {
    final g = goal(
      min: const Duration(hours: 2),
      max: const Duration(hours: 5),
    );
    final p = goalProgress(g, entries, now);

    test('counts only today, only Studying, including the running session', () {
      // 00:00–01:00 (clipped) + 1.5 h + 1 h running.
      expect(p.tracked, const Duration(hours: 3, minutes: 30));
    });

    test('minimum: reached, with percentage', () {
      expect(p.minimumReached, isTrue);
      expect(p.minimumFraction, closeTo(1.75, 1e-9));
      expect(p.untilMinimum, Duration.zero);
    });

    test('maximum: used share and remaining allowance', () {
      expect(p.maximumExceeded, isFalse);
      expect(p.maximumFraction, closeTo(0.7, 1e-9));
      expect(p.remainingAllowance, const Duration(hours: 1, minutes: 30));
      expect(p.overMaximum, Duration.zero);
    });
  });

  test('spec example: 7 days from Monday 00:00, min 10 h, max 20 h', () {
    final g = goal(
      unit: GoalUnit.week,
      min: const Duration(hours: 10),
      max: const Duration(hours: 20),
    );
    final p = goalProgress(g, entries, now);
    expect(p.period.start, DateTime(2026, 11, 9));
    // Wed 22:00–24:00 is inside this week too.
    expect(p.tracked, const Duration(hours: 5, minutes: 30));
    expect(p.minimumReached, isFalse);
    expect(p.untilMinimum, const Duration(hours: 4, minutes: 30));
    expect(p.minimumFraction, closeTo(0.55, 1e-9));
  });

  test('spec example: monthly from the 1st, min 40 h, no maximum', () {
    final g = goal(
      unit: GoalUnit.month,
      anchor: const GoalAnchor(year: 2026, month: 1, day: 1, minuteOfDay: 0),
      min: const Duration(hours: 40),
    );
    final p = goalProgress(g, entries, now);
    expect(p.period.start, DateTime(2026, 11));
    expect(p.maximum, isNull);
    expect(p.maximumFraction, isNull);
    expect(p.remainingAllowance, isNull);
    expect(p.minimumFraction, closeTo(5.5 / 40, 1e-9));
  });

  test('maximum only, exceeded', () {
    final p = goalProgress(goal(max: const Duration(hours: 3)), entries, now);
    expect(p.minimum, isNull);
    expect(p.minimumReached, isFalse);
    expect(p.maximumExceeded, isTrue);
    expect(p.overMaximum, const Duration(minutes: 30));
    expect(p.remainingAllowance, Duration.zero);
  });

  test('a session crossing a period boundary counts only its part', () {
    // 4-hour periods from 00:00: 08:00–12:00 contains 09:00–10:30 (1.5 h);
    // 12:00–16:00 contains 14:00–15:00 of the running session.
    final g = goal(
      unit: GoalUnit.hour,
      length: 4,
      min: const Duration(hours: 1),
    );
    expect(
      goalProgress(g, entries, thu(11)).tracked,
      const Duration(hours: 1, minutes: 30),
    );
    expect(goalProgress(g, entries, now).tracked, const Duration(hours: 1));
  });

  test('a new period starts from zero', () {
    final g = goal(min: const Duration(hours: 1));
    final tomorrow = DateTime(2026, 11, 13, 0, 0, 30);
    final p = goalProgress(g, [e(study, thu(14), tomorrow)], tomorrow);
    expect(p.tracked, const Duration(seconds: 30));
    expect(p.minimumReached, isFalse);
  });

  test(
    'exactly at the minimum counts as reached; at the maximum not exceeded',
    () {
      final g = goal(
        min: const Duration(hours: 1),
        max: const Duration(hours: 1),
      );
      final p = goalProgress(g, [e(study, thu(9), thu(10))], now);
      expect(p.minimumReached, isTrue);
      expect(p.maximumExceeded, isFalse);
      expect(p.remainingAllowance, Duration.zero);
    },
  );
}
