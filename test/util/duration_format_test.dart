import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/util/duration_format.dart';

void main() {
  test('formatClock', () {
    expect(formatClock(Duration.zero), '0:00:00');
    expect(formatClock(const Duration(minutes: 5, seconds: 9)), '0:05:09');
    expect(
      formatClock(const Duration(hours: 1, minutes: 42, seconds: 15)),
      '1:42:15',
    );
    expect(formatClock(const Duration(hours: 27)), '27:00:00');
    expect(formatClock(const Duration(milliseconds: 999)), '0:00:00');
    expect(formatClock(const Duration(seconds: -5)), '0:00:00');
  });

  test('formatTotal', () {
    expect(formatTotal(Duration.zero), '0m');
    expect(formatTotal(const Duration(seconds: 59)), '0m');
    expect(formatTotal(const Duration(minutes: 42)), '42m');
    expect(formatTotal(const Duration(hours: 2, minutes: 42)), '2h 42m');
    expect(formatTotal(const Duration(hours: 5)), '5h 0m');
    expect(formatTotal(const Duration(hours: 130, minutes: 1)), '130h 1m');
    expect(formatTotal(const Duration(minutes: -3)), '0m');
    // Seconds are summed before formatting, so 3 x 40 s shows 2m.
    expect(formatTotal(const Duration(seconds: 40) * 3), '2m');
  });

  test('formatDurationPrecise keeps seconds below an hour', () {
    expect(formatDurationPrecise(const Duration(seconds: 40)), '40s');
    expect(
      formatDurationPrecise(const Duration(minutes: 1, seconds: 37)),
      '1m 37s',
    );
    expect(formatDurationPrecise(const Duration(minutes: 1)), '1m 0s');
    expect(
      formatDurationPrecise(const Duration(hours: 2, minutes: 5, seconds: 9)),
      '2h 5m',
    );
    expect(formatDurationPrecise(const Duration(seconds: -1)), '0s');
  });
}
