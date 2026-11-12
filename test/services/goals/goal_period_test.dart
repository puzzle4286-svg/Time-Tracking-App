import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/services/goals/goal_period.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

import '../../support/matchers.dart';

void main() {
  GoalAnchor at(int y, int m, int d, [int h = 0, int min = 0]) =>
      GoalAnchor(year: y, month: m, day: d, minuteOfDay: h * 60 + min);

  void expectPeriod(TimeRange r, DateTime start, DateTime end) {
    expect(r.start, isMoment(start), reason: 'start');
    expect(r.end, isMoment(end), reason: 'end');
  }

  group('days', () {
    final midnight = at(2026, 11, 1);

    test('24 h from 00:00 is the local calendar day', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.day, 1, midnight, DateTime(2026, 11, 12, 15)),
        DateTime(2026, 11, 12),
        DateTime(2026, 11, 13),
      );
    });

    test('a later start time of day shifts the boundary', () {
      final six = at(2026, 11, 1, 6);
      expectPeriod(
        goalPeriodAt(GoalUnit.day, 1, six, DateTime(2026, 11, 12, 5, 59)),
        DateTime(2026, 11, 11, 6),
        DateTime(2026, 11, 12, 6),
      );
      expectPeriod(
        goalPeriodAt(GoalUnit.day, 1, six, DateTime(2026, 11, 12, 6)),
        DateTime(2026, 11, 12, 6),
        DateTime(2026, 11, 13, 6),
      );
    });

    test('48 h periods are aligned to the anchor date', () {
      // Anchor 1 Nov: periods 1–3, 3–5, …, 11–13 Nov.
      expectPeriod(
        goalPeriodAt(GoalUnit.day, 2, midnight, DateTime(2026, 11, 12, 1)),
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 13),
      );
    });

    test('the boundary instant belongs to the new period', () {
      final r = goalPeriodAt(GoalUnit.day, 1, midnight, DateTime(2026, 11, 13));
      expect(r.start, isMoment(DateTime(2026, 11, 13)));
    });

    test('times before the anchor still get a period', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.day, 3, midnight, DateTime(2026, 10, 30, 12)),
        DateTime(2026, 10, 29),
        DateTime(2026, 11, 1),
      );
    });
  });

  group('weeks', () {
    final monday = at(2026, 11, 2); // a Monday

    test('7 days from Monday 00:00', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.week, 1, monday, DateTime(2026, 11, 12, 15)),
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
      );
    });

    test('Sunday 23:59 is still the same week', () {
      final r = goalPeriodAt(
        GoalUnit.week,
        1,
        monday,
        DateTime(2026, 11, 15, 23, 59),
      );
      expect(r.start, isMoment(DateTime(2026, 11, 9)));
    });

    test('two-week periods', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.week, 2, monday, DateTime(2026, 11, 12)),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 16),
      );
    });
  });

  group('months', () {
    test('from the first of the month', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.month, 1, at(2026, 1, 1), DateTime(2026, 11, 12)),
        DateTime(2026, 11),
        DateTime(2026, 12),
      );
    });

    test('a start on the 31st is clamped to short months', () {
      final a = at(2026, 1, 31);
      expectPeriod(
        goalPeriodAt(GoalUnit.month, 1, a, DateTime(2026, 2, 15)),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
      );
      expectPeriod(
        goalPeriodAt(GoalUnit.month, 1, a, DateTime(2026, 3, 1)),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      );
    });

    test('quarterly periods across a year boundary', () {
      expectPeriod(
        goalPeriodAt(GoalUnit.month, 3, at(2026, 1, 1), DateTime(2027, 2, 10)),
        DateTime(2027),
        DateTime(2027, 4),
      );
    });
  });

  group('hours', () {
    test('4-hour periods from an anchor', () {
      expectPeriod(
        goalPeriodAt(
          GoalUnit.hour,
          4,
          at(2026, 11, 12, 6),
          DateTime(2026, 11, 12, 13),
        ),
        DateTime(2026, 11, 12, 10),
        DateTime(2026, 11, 12, 14),
      );
    });

    test('1-hour periods', () {
      expectPeriod(
        goalPeriodAt(
          GoalUnit.hour,
          1,
          at(2026, 11, 1),
          DateTime(2026, 11, 12, 13, 59),
        ),
        DateTime(2026, 11, 12, 13),
        DateTime(2026, 11, 12, 14),
      );
    });

    test('rejects a zero length', () {
      expect(
        () => goalPeriodAt(GoalUnit.hour, 0, at(2026, 1, 1), DateTime(2026)),
        throwsArgumentError,
      );
    });
  });

  group("daylight saving (this process's local timezone)", () {
    final dstDays = [
      for (
        var d = DateTime(2026);
        d.year == 2026;
        d = DateTime(d.year, d.month, d.day + 1)
      )
        if (localDay(d).duration != const Duration(hours: 24)) d,
    ];
    final skip = dstDays.isEmpty ? 'Local timezone has no DST in 2026' : null;

    test('daily periods follow the calendar: 23 or 25 hours', () {
      for (final d in dstDays) {
        final r = goalPeriodAt(
          GoalUnit.day,
          1,
          at(2026, 1, 1),
          DateTime(d.year, d.month, d.day, 12),
        );
        expect(r.start, isMoment(startOfLocalDay(d)));
        expect(r.duration, localDay(d).duration);
        expect(r.duration, isNot(const Duration(hours: 24)));
      }
    }, skip: skip);

    test('hour periods stay exactly their length across DST', () {
      for (final d in dstDays) {
        var t = DateTime(d.year, d.month, d.day);
        for (var i = 0; i < 30; i++) {
          final r = goalPeriodAt(GoalUnit.hour, 1, at(2026, 1, 1), t);
          expect(r.duration, const Duration(hours: 1));
          expect(r.contains(t), isTrue);
          t = t.add(const Duration(minutes: 50));
        }
      }
    }, skip: skip);
  });

  test('every instant lies in exactly the period computed for it', () {
    final rules = [
      (GoalUnit.hour, 5, at(2026, 3, 1, 7, 30)),
      (GoalUnit.day, 1, at(2026, 1, 1, 4)),
      (GoalUnit.day, 3, at(2026, 2, 27)),
      (GoalUnit.week, 1, at(2026, 1, 5, 9)),
      (GoalUnit.month, 1, at(2026, 1, 31, 18)),
      (GoalUnit.month, 2, at(2025, 12, 15)),
    ];
    for (final (unit, length, anchor) in rules) {
      var t = DateTime(2026, 1, 1);
      while (t.isBefore(DateTime(2026, 12, 31))) {
        final r = goalPeriodAt(unit, length, anchor, t);
        expect(r.contains(t), isTrue, reason: '$unit×$length at $t');
        // The next period starts exactly where this one ends.
        final next = goalPeriodAt(unit, length, anchor, r.end);
        expect(next.start, isMoment(r.end));
        t = t.add(const Duration(hours: 37));
      }
    }
  });
}
