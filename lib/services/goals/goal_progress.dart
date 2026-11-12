import '../../models/goal.dart';
import '../../models/time_entry.dart';
import '../tracking/durations.dart';
import '../tracking/time_range.dart';
import 'goal_period.dart';

/// Progress of a goal in one period, computed from recorded entries only.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.period,
    required this.tracked,
  });

  final Goal goal;
  final TimeRange period;

  /// Time recorded for the goal's activity inside [period] (up to now).
  final Duration tracked;

  Duration? get minimum => goal.minimum;
  Duration? get maximum => goal.maximum;

  /// tracked / minimum (may exceed 1).
  double? get minimumFraction =>
      minimum == null ? null : tracked.inMicroseconds / minimum!.inMicroseconds;

  bool get minimumReached => minimum != null && tracked >= minimum!;

  /// Time still needed to reach the minimum (zero once reached).
  Duration? get untilMinimum {
    final m = minimum;
    if (m == null) return null;
    return tracked >= m ? Duration.zero : m - tracked;
  }

  /// tracked / maximum (may exceed 1).
  double? get maximumFraction =>
      maximum == null ? null : tracked.inMicroseconds / maximum!.inMicroseconds;

  bool get maximumExceeded => maximum != null && tracked > maximum!;

  /// Allowance left before the maximum (zero once used up).
  Duration? get remainingAllowance {
    final m = maximum;
    if (m == null) return null;
    return tracked >= m ? Duration.zero : m - tracked;
  }

  /// How far the maximum is exceeded (zero if not).
  Duration? get overMaximum {
    final m = maximum;
    if (m == null) return null;
    return tracked > m ? tracked - m : Duration.zero;
  }
}

/// Progress of [goal] in its period containing [now], from [entries] (any
/// entries overlapping that period; other activities are ignored).
GoalProgress goalProgress(
  Goal goal,
  Iterable<TimeEntry> entries,
  DateTime now,
) {
  final period = currentGoalPeriod(goal, now);
  return GoalProgress(
    goal: goal,
    period: period,
    tracked: trackedInRange(entries, period, now, activityId: goal.activityId),
  );
}
