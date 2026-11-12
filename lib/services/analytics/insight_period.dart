import '../../util/date_format.dart';
import '../tracking/time_range.dart';

/// The period granularity selected in Insights.
enum InsightUnit { day, week, month, year, all }

/// A selected Insights period: a unit and any instant inside it.
class InsightPeriod {
  const InsightPeriod(this.unit, this.anchor);

  final InsightUnit unit;

  /// Any instant inside the period (local calendar is used).
  final DateTime anchor;

  /// The local calendar range. Weeks start on Monday. For [InsightUnit.all]
  /// the range is [firstEntry, now].
  TimeRange range({required DateTime now, DateTime? firstEntry}) {
    final a = anchor.toLocal();
    return switch (unit) {
      InsightUnit.day => localDay(a),
      InsightUnit.week => TimeRange(
        DateTime(a.year, a.month, a.day - (a.weekday - 1)),
        DateTime(a.year, a.month, a.day - (a.weekday - 1) + 7),
      ),
      InsightUnit.month => TimeRange(
        DateTime(a.year, a.month),
        DateTime(a.year, a.month + 1),
      ),
      InsightUnit.year => TimeRange(DateTime(a.year), DateTime(a.year + 1)),
      InsightUnit.all => TimeRange(
        (firstEntry ?? now).isBefore(now) ? firstEntry ?? now : now,
        now,
      ),
    };
  }

  /// The period [steps] units before (negative) or after (positive).
  InsightPeriod shift(int steps) {
    final a = anchor.toLocal();
    final moved = switch (unit) {
      InsightUnit.day => DateTime(a.year, a.month, a.day + steps, 12),
      InsightUnit.week => DateTime(a.year, a.month, a.day + 7 * steps, 12),
      // Day 1 avoids month-end overflow (31 Jan + 1 month).
      InsightUnit.month => DateTime(a.year, a.month + steps, 1, 12),
      InsightUnit.year => DateTime(a.year + steps, 1, 1, 12),
      InsightUnit.all => a,
    };
    return InsightPeriod(unit, moved);
  }

  InsightPeriod get previous => shift(-1);
  InsightPeriod get next => shift(1);

  bool contains(DateTime t, {required DateTime now}) =>
      range(now: now).contains(t);

  /// Whether the period has not finished yet.
  bool isInProgress(DateTime now) =>
      unit == InsightUnit.all || range(now: now).contains(now);

  /// Whether the period lies entirely in the future.
  bool isFuture(DateTime now) =>
      unit != InsightUnit.all && range(now: now).start.isAfter(now);

  /// Short label, e.g. "Today", "9 – 15 Nov 2026", "November 2026", "2026".
  String label(DateTime now) {
    final r = range(now: now);
    return switch (unit) {
      InsightUnit.day => formatDayLabel(r.start, now),
      InsightUnit.week => _weekLabel(r),
      InsightUnit.month => '${monthName(r.start.month)} ${r.start.year}',
      InsightUnit.year => '${r.start.year}',
      InsightUnit.all => 'All time',
    };
  }

  /// How the period is referred to in comparisons, e.g. "This week",
  /// "Last month", "Today", or the label for other periods.
  String relativeName(DateTime now) {
    final current = InsightPeriod(unit, now);
    final same = current.range(now: now).start == range(now: now).start;
    final last =
        current.previous.range(now: now).start == range(now: now).start;
    final noun = switch (unit) {
      InsightUnit.day => null,
      InsightUnit.week => 'week',
      InsightUnit.month => 'month',
      InsightUnit.year => 'year',
      InsightUnit.all => null,
    };
    if (unit == InsightUnit.day) return label(now);
    if (noun != null && same) return 'This $noun';
    if (noun != null && last) return 'Last $noun';
    return label(now);
  }

  static String _weekLabel(TimeRange r) {
    final s = r.start;
    final e = DateTime(r.end.year, r.end.month, r.end.day - 1);
    if (s.year != e.year) {
      return '${s.day} ${monthShort(s.month)} ${s.year} – '
          '${e.day} ${monthShort(e.month)} ${e.year}';
    }
    if (s.month != e.month) {
      return '${s.day} ${monthShort(s.month)} – '
          '${e.day} ${monthShort(e.month)} ${e.year}';
    }
    return '${s.day} – ${e.day} ${monthShort(s.month)} ${s.year}';
  }
}
