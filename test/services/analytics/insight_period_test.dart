import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/analytics/insight_period.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

void main() {
  final now = DateTime(2026, 11, 12, 15); // Thursday
  InsightPeriod p(InsightUnit u, [DateTime? t]) => InsightPeriod(u, t ?? now);

  test('ranges follow the local calendar; weeks start on Monday', () {
    expect(p(InsightUnit.day).range(now: now).start, DateTime(2026, 11, 12));
    final week = p(InsightUnit.week).range(now: now);
    expect(week.start, DateTime(2026, 11, 9));
    expect(week.end, DateTime(2026, 11, 16));
    final month = p(InsightUnit.month).range(now: now);
    expect((month.start, month.end), (DateTime(2026, 11), DateTime(2026, 12)));
    final year = p(InsightUnit.year).range(now: now);
    expect((year.start, year.end), (DateTime(2026), DateTime(2027)));
  });

  test('all time spans from the first entry to now', () {
    final r = p(
      InsightUnit.all,
    ).range(now: now, firstEntry: DateTime(2026, 1, 5));
    expect((r.start, r.end), (DateTime(2026, 1, 5), now));
  });

  test('shifting moves by whole periods', () {
    expect(
      p(InsightUnit.day).shift(-1).range(now: now).start,
      DateTime(2026, 11, 11),
    );
    expect(
      p(InsightUnit.week).previous.range(now: now).start,
      DateTime(2026, 11, 2),
    );
    // From 31 March one month back is February, not 3 March.
    expect(
      p(
        InsightUnit.month,
        DateTime(2026, 3, 31),
      ).previous.range(now: now).start,
      DateTime(2026, 2),
    );
    expect(p(InsightUnit.year).shift(-2).range(now: now).start, DateTime(2024));
  });

  test('a week across the year boundary', () {
    final r = p(InsightUnit.week, DateTime(2026, 1, 1)).range(now: now);
    expect(r.start, DateTime(2025, 12, 29));
    expect(
      p(InsightUnit.week, DateTime(2026, 1, 1)).label(now),
      '29 Dec 2025 – 4 Jan 2026',
    );
  });

  test('labels', () {
    expect(p(InsightUnit.day).label(now), 'Today');
    expect(p(InsightUnit.day).previous.label(now), 'Yesterday');
    expect(p(InsightUnit.week).label(now), '9 – 15 Nov 2026');
    expect(
      p(InsightUnit.week, DateTime(2026, 12, 1)).label(now),
      '30 Nov – 6 Dec 2026',
    );
    expect(p(InsightUnit.month).label(now), 'November 2026');
    expect(p(InsightUnit.year).label(now), '2026');
    expect(p(InsightUnit.all).label(now), 'All time');
  });

  test('relative names for comparisons', () {
    expect(p(InsightUnit.week).relativeName(now), 'This week');
    expect(p(InsightUnit.week).previous.relativeName(now), 'Last week');
    expect(p(InsightUnit.month).previous.relativeName(now), 'Last month');
    expect(p(InsightUnit.month).shift(-2).relativeName(now), 'September 2026');
    expect(p(InsightUnit.day).relativeName(now), 'Today');
  });

  test('in progress and future', () {
    expect(p(InsightUnit.week).isInProgress(now), isTrue);
    expect(p(InsightUnit.week).previous.isInProgress(now), isFalse);
    expect(p(InsightUnit.week).next.isFuture(now), isTrue);
    expect(p(InsightUnit.all).isInProgress(now), isTrue);
  });

  test('a day period has the real local day length', () {
    for (
      var d = DateTime(2026);
      d.year == 2026;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      expect(
        p(InsightUnit.day, d).range(now: now).duration,
        localDay(d).duration,
      );
    }
  });
}
