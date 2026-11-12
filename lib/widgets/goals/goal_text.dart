import '../../models/goal.dart';
import '../../util/date_format.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _two(int n) => n.toString().padLeft(2, '0');

String goalTimeOfDay(GoalAnchor a) => '${_two(a.hour)}:${_two(a.minute)}';

String goalUnitLabel(GoalUnit unit, int length) {
  final one = length == 1;
  return switch (unit) {
    GoalUnit.hour => one ? 'hour' : 'hours',
    GoalUnit.day => one ? 'day' : 'days',
    GoalUnit.week => one ? 'week' : 'weeks',
    GoalUnit.month => one ? 'month' : 'months',
  };
}

/// Human description of a goal's period rule, e.g. "Every day from 00:00",
/// "Every week from Monday 00:00", "Every 2 months from day 15, 08:00".
String describeGoalPeriod(Goal g) {
  final a = g.anchor;
  final every = g.length == 1
      ? 'Every ${goalUnitLabel(g.unit, 1)}'
      : 'Every ${g.length} ${goalUnitLabel(g.unit, g.length)}';
  final time = goalTimeOfDay(a);
  return switch (g.unit) {
    GoalUnit.hour => '$every from ${formatMoment(a.toLocal())}',
    GoalUnit.day =>
      g.length == 1
          ? '$every from $time'
          : '$every from ${formatShortDate(a.toLocal())}, $time',
    GoalUnit.week =>
      g.length == 1
          ? '$every from ${_weekdayNames[a.toLocal().weekday - 1]} $time'
          : '$every from ${formatShortDate(a.toLocal())}, $time',
    GoalUnit.month => '$every from day ${a.day}, $time',
  };
}

/// Short summary of the targets, e.g. "min 2h 0m · max 5h 0m".
String describeGoalTargets(Goal g, String Function(Duration) format) => [
  if (g.minimum != null) 'min ${format(g.minimum!)}',
  if (g.maximum != null) 'max ${format(g.maximum!)}',
].join(' · ');
