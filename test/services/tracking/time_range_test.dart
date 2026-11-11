import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/tracking/durations.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

void main() {
  group('local day helpers', () {
    test('start of day and next midnight', () {
      final t = DateTime(2026, 11, 11, 15, 42);
      expect(startOfLocalDay(t), DateTime(2026, 11, 11));
      expect(nextLocalMidnight(t), DateTime(2026, 11, 12));
    });

    test('midnight itself belongs to the day it starts', () {
      final midnight = DateTime(2026, 11, 11);
      expect(startOfLocalDay(midnight), midnight);
      expect(nextLocalMidnight(midnight), DateTime(2026, 11, 12));
    });

    test('month and year rollover', () {
      expect(nextLocalMidnight(DateTime(2026, 1, 31, 12)), DateTime(2026, 2));
      expect(nextLocalMidnight(DateTime(2026, 12, 31, 23)), DateTime(2027));
      expect(
        nextLocalMidnight(DateTime(2028, 2, 28, 1)),
        DateTime(2028, 2, 29),
      );
    });

    test('accepts UTC input and works in local time', () {
      final local = DateTime(2026, 11, 11, 23, 30);
      expect(localDay(local.toUtc()).start, DateTime(2026, 11, 11));
    });
  });

  group('TimeRange', () {
    final range = TimeRange(DateTime(2026, 1, 1, 10), DateTime(2026, 1, 1, 12));

    test('rejects an end before the start', () {
      expect(
        () => TimeRange(DateTime(2026, 1, 2), DateTime(2026, 1, 1)),
        throwsArgumentError,
      );
    });

    test('overlap clips to the range', () {
      expect(
        range.overlap(DateTime(2026, 1, 1, 9), DateTime(2026, 1, 1, 11)),
        const Duration(hours: 1),
      );
      expect(
        range.overlap(DateTime(2026, 1, 1, 8), DateTime(2026, 1, 1, 9)),
        Duration.zero,
      );
      expect(
        range.overlap(DateTime(2026, 1, 1, 9), DateTime(2026, 1, 1, 13)),
        const Duration(hours: 2),
      );
    });

    test('contains is half-open', () {
      expect(range.contains(range.start), isTrue);
      expect(range.contains(range.end), isFalse);
    });
  });

  group('trackedInRange', () {
    TimeEntry entry(int activity, int fromHour, int? toHour) => TimeEntry(
      id: fromHour,
      activityId: activity,
      start: DateTime(2026, 1, 1, fromHour),
      end: toHour == null ? null : DateTime(2026, 1, 1, toHour),
    );

    final day = localDay(DateTime(2026, 1, 1));
    final now = DateTime(2026, 1, 1, 20);
    final entries = [
      entry(1, 8, 9),
      entry(2, 9, 12),
      entry(1, 12, 14),
      entry(2, 14, 18),
      entry(1, 18, null), // open, measured to `now`
    ];

    test('sums all sessions of one activity', () {
      expect(
        trackedInRange(entries, day, now, activityId: 1),
        const Duration(hours: 5),
      );
    });

    test('sums every activity when none is given', () {
      expect(trackedInRange(entries, day, now), const Duration(hours: 12));
    });

    test('clips entries to the range', () {
      final morning = TimeRange(
        DateTime(2026, 1, 1, 8, 30),
        DateTime(2026, 1, 1, 10),
      );
      expect(
        trackedInRange(entries, morning, now),
        const Duration(minutes: 90),
      );
    });

    test('an open entry starting after now counts as zero', () {
      final future = [entry(1, 21, null)];
      expect(trackedInRange(future, day, now), Duration.zero);
    });
  });
}
