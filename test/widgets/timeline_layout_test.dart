import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/tracking/time_range.dart';
import 'package:time_tracker/widgets/timeline/timeline_layout.dart';

import '../support/day_entries.dart';

void main() {
  final day = localDay(DateTime(2026, 11, 9));
  const ppm = 4.0;
  const minH = 30.0;

  TimelineLayout layout(List<(int, int, int)> spans, {DateTime? end}) =>
      TimelineLayout.compute(
        day: day,
        entries: [
          for (final (i, (from, to, _)) in spans.indexed)
            dayEntry(
              i + 1,
              'A$i',
              DateTime(2026, 11, 9).add(Duration(minutes: from)),
              DateTime(2026, 11, 9).add(Duration(minutes: to)),
            ),
        ],
        end: end ?? day.end,
        now: DateTime(2026, 11, 12),
        pixelsPerMinute: ppm,
        minBlockHeight: minH,
      );

  test('long entries are exactly proportional', () {
    final l = layout([(0, 60, 0), (60, 180, 0)]);
    expect(l.blocks[0].height, 60 * ppm);
    expect(l.blocks[1].top, 60 * ppm);
    expect(l.blocks[1].height, 120 * ppm);
    expect(l.height, 24 * 60 * ppm);
  });

  test('every entry gets at least the minimum height, in order', () {
    // 1 min, 30 s-ish (0 min), 2 min entries back to back.
    final l = layout([(600, 601, 0), (601, 601, 0), (601, 603, 0)]);
    expect(l.blocks, hasLength(3));
    for (final b in l.blocks) {
      expect(b.height, greaterThanOrEqualTo(minH));
    }
    for (var i = 1; i < l.blocks.length; i++) {
      expect(
        l.blocks[i].top,
        greaterThanOrEqualTo(l.blocks[i - 1].top + l.blocks[i - 1].height),
      );
    }
  });

  test('time after a stretched block keeps its proportional spacing', () {
    final l = layout([(600, 601, 0), (661, 721, 0)]);
    final first = l.blocks[0];
    final second = l.blocks[1];
    // 60 min gap between the entries -> 240 px gap between the blocks.
    expect(second.top - (first.top + first.height), 60 * ppm);
    expect(second.height, 60 * ppm);
  });

  test('yOf is monotonic and matches block edges', () {
    final l = layout([(600, 601, 0), (661, 721, 0)]);
    final b = l.blocks[1];
    expect(l.yOf(DateTime(2026, 11, 9, 11, 1)), b.top);
    expect(l.yOf(DateTime(2026, 11, 9, 12, 1)), b.top + b.height);
    var last = -1.0;
    for (var m = 0; m < 24 * 60; m += 7) {
      final y = l.yOf(DateTime(2026, 11, 9).add(Duration(minutes: m)));
      expect(y, greaterThanOrEqualTo(last));
      last = y;
    }
  });

  test('today ends at the given end', () {
    final l = layout([(0, 60, 0)], end: DateTime(2026, 11, 9, 2));
    expect(l.height, 120 * ppm);
  });

  test('overlapping entries are drawn after each other', () {
    final l = layout([(0, 120, 0), (60, 180, 0)]);
    expect(l.blocks[1].top, l.blocks[0].top + l.blocks[0].height);
  });

  test('timeOf is the inverse of yOf', () {
    final l = layout([(600, 601, 0), (661, 721, 0), (721, 722, 0)]);
    for (var m = 0; m < 24 * 60; m += 13) {
      final t = DateTime(2026, 11, 9).add(Duration(minutes: m));
      final back = l.timeOf(l.yOf(t));
      expect(back.difference(t).inMilliseconds.abs(), lessThan(5));
    }
  });
}
