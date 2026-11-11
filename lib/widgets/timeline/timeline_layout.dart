import '../../services/history/history_service.dart';
import '../../services/tracking/time_range.dart';

/// A positioned entry in a day's timeline.
class TimelineBlock {
  const TimelineBlock(this.item, this.top, this.height);

  final DayEntry item;
  final double top;
  final double height;
}

/// Vertical layout of one day: time maps to y at [pixelsPerMinute], except
/// that every entry is at least [minBlockHeight] tall so it can be labelled.
/// Hour marks use the same mapping ([yOf]), so they stay consistent with the
/// blocks. Long entries remain exactly proportional.
class TimelineLayout {
  TimelineLayout._(this._knots, this.blocks);

  /// Lays out [entries] (chronological) of [day], drawn up to [end].
  factory TimelineLayout.compute({
    required TimeRange day,
    required List<DayEntry> entries,
    required DateTime end,
    required DateTime now,
    required double pixelsPerMinute,
    required double minBlockHeight,
  }) {
    double px(Duration d) => d.inMicroseconds / 60e6 * pixelsPerMinute;

    final knots = <(DateTime, double)>[(day.start, 0)];
    final blocks = <TimelineBlock>[];
    var cursorTime = day.start;
    var cursorY = 0.0;

    for (final item in entries) {
      // Overlapping entries (possible after edits) are drawn after the
      // previous one rather than on top of it.
      final start = item.start.isAfter(cursorTime) ? item.start : cursorTime;
      final rawEnd = item.end ?? now;
      final stop = rawEnd.isAfter(end) ? end : rawEnd;
      final top = cursorY + px(start.difference(cursorTime));
      final natural = px(
        stop.isAfter(start) ? stop.difference(start) : Duration.zero,
      );
      final height = natural < minBlockHeight ? minBlockHeight : natural;

      knots.add((start, top));
      blocks.add(TimelineBlock(item, top, height));
      final endTime = stop.isAfter(start) ? stop : start;
      cursorTime = endTime;
      cursorY = top + height;
      knots.add((endTime, cursorY));
    }
    if (end.isAfter(cursorTime)) {
      knots.add((end, cursorY + px(end.difference(cursorTime))));
    }
    return TimelineLayout._(knots, blocks);
  }

  final List<(DateTime, double)> _knots;
  final List<TimelineBlock> blocks;

  double get height => _knots.last.$2;

  /// Y position of instant [t], interpolated between layout knots.
  double yOf(DateTime t) {
    if (!t.isAfter(_knots.first.$1)) return 0;
    for (var i = 1; i < _knots.length; i++) {
      final (t1, y1) = _knots[i];
      if (!t.isAfter(t1)) {
        final (t0, y0) = _knots[i - 1];
        final span = t1.difference(t0).inMicroseconds;
        if (span == 0) return y1;
        return y0 + (y1 - y0) * t.difference(t0).inMicroseconds / span;
      }
    }
    return height;
  }

  /// Instant drawn at [y]; the inverse of [yOf].
  DateTime timeOf(double y) {
    if (y <= 0) return _knots.first.$1;
    for (var i = 1; i < _knots.length; i++) {
      final (t1, y1) = _knots[i];
      if (y <= y1) {
        final (t0, y0) = _knots[i - 1];
        if (y1 == y0) return t1;
        final span = t1.difference(t0).inMicroseconds;
        return t0.add(
          Duration(microseconds: (span * (y - y0) / (y1 - y0)).round()),
        );
      }
    }
    return _knots.last.$1;
  }
}
