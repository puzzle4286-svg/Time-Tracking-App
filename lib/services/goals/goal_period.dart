import '../../models/goal.dart';
import '../tracking/time_range.dart';

/// The period of a goal rule that contains [t].
///
/// - [GoalUnit.hour]: fixed-length periods of `length` hours from the
///   anchor instant (real elapsed time, unaffected by DST).
/// - [GoalUnit.day] / [GoalUnit.week]: periods start at the anchor's local
///   time of day every `length` days / weeks, following the local calendar,
///   so a period containing a DST change is 23 or 25 hours (× length).
/// - [GoalUnit.month]: periods start on the anchor's day of month (clamped
///   to the month's last day, e.g. the 31st becomes 28 Feb) every `length`
///   months.
///
/// Works for [t] before the anchor too (periods extend backwards).
TimeRange goalPeriodAt(
  GoalUnit unit,
  int length,
  GoalAnchor anchor,
  DateTime t,
) {
  if (length < 1) throw ArgumentError.value(length, 'length', 'Must be >= 1');
  final local = t.toLocal();
  return switch (unit) {
    GoalUnit.hour => _hourPeriod(length, anchor, local),
    GoalUnit.day => _calendarPeriod(
      length,
      anchor,
      local,
      (k) => _shiftDays(anchor, k * length),
    ),
    GoalUnit.week => _calendarPeriod(
      length * 7,
      anchor,
      local,
      (k) => _shiftDays(anchor, k * length * 7),
    ),
    GoalUnit.month => _monthPeriod(length, anchor, local),
  };
}

/// The current period of [goal] at [now].
TimeRange currentGoalPeriod(Goal goal, DateTime now) =>
    goalPeriodAt(goal.unit, goal.length, goal.anchor, now);

TimeRange _hourPeriod(int length, GoalAnchor anchor, DateTime t) {
  final origin = anchor.toLocal();
  final step = Duration(hours: length);
  final k = _floorDiv(t.difference(origin).inMicroseconds, step.inMicroseconds);
  final start = origin.add(step * k);
  return TimeRange(start, start.add(step));
}

DateTime _shiftDays(GoalAnchor a, int days) =>
    DateTime(a.year, a.month, a.day + days, a.hour, a.minute);

/// Day/week periods: [startOf](k) is the k-th period start; [stepDays] is
/// only used to estimate k from the calendar-day distance.
TimeRange _calendarPeriod(
  int stepDays,
  GoalAnchor a,
  DateTime t,
  DateTime Function(int k) startOf,
) {
  // Count calendar days in UTC so DST does not distort the estimate.
  final days = DateTime.utc(
    t.year,
    t.month,
    t.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  return _settle(_floorDiv(days, stepDays), t, startOf);
}

TimeRange _monthPeriod(int length, GoalAnchor a, DateTime t) {
  DateTime startOf(int k) {
    final m0 = a.month - 1 + k * length;
    final year = a.year + _floorDiv(m0, 12);
    final month = m0 - _floorDiv(m0, 12) * 12 + 1;
    final last = DateTime.utc(year, month + 1, 0).day;
    final day = a.day > last ? last : a.day;
    return DateTime(year, month, day, a.hour, a.minute);
  }

  final months = (t.year - a.year) * 12 + (t.month - a.month);
  return _settle(_floorDiv(months, length), t, startOf);
}

/// Adjusts the estimate [k] so that startOf(k) <= t < startOf(k + 1).
TimeRange _settle(int k, DateTime t, DateTime Function(int k) startOf) {
  while (startOf(k).isAfter(t)) {
    k--;
  }
  while (!startOf(k + 1).isAfter(t)) {
    k++;
  }
  return TimeRange(startOf(k), startOf(k + 1));
}

int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}
