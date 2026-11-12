import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/services/goals/goal_progress.dart';
import 'package:time_tracker/services/tracking/time_range.dart';
import 'package:time_tracker/widgets/goals/goal_bars.dart';

GoalProgress progress(Duration tracked, {Duration? min, Duration? max}) =>
    GoalProgress(
      goal: Goal(
        id: 1,
        activityId: 1,
        name: null,
        unit: GoalUnit.day,
        length: 1,
        anchor: const GoalAnchor(year: 2026, month: 11, day: 9, minuteOfDay: 0),
        minimum: min,
        maximum: max,
        enabled: true,
        createdAt: DateTime.utc(2026),
      ),
      period: TimeRange(DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 10)),
      tracked: tracked,
    );

const h = Duration(hours: 1);
const m = Duration(minutes: 1);

void main() {
  group('linear scale', () {
    test('ends 25 % beyond the largest target', () {
      expect(linearScaleEnd(progress(h, min: h, max: h * 2)), h * 2.5);
      expect(linearScaleEnd(progress(h, min: h)), h * 1.25);
      expect(linearScaleEnd(progress(h, max: h * 4)), h * 5);
    });

    test('fractions are clamped', () {
      expect(linearFraction(h, h * 4), 0.25);
      expect(linearFraction(h * 9, h * 4), 1);
      expect(linearFraction(-h, h * 4), 0);
      expect(linearFraction(h, Duration.zero), 0);
    });
  });

  test('short labels', () {
    expect(shortDuration(h), '1h');
    expect(shortDuration(m * 90), '1h 30m');
    expect(shortDuration(m * 45), '45m');
  });
}
