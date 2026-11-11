import 'package:flutter/material.dart';

import '../../services/history/history_service.dart';
import '../../services/tracking/time_range.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';

/// Vertical timeline of one local day. Height is proportional to time:
/// [pixelsPerMinute] × the real length of the day (23/25 h on DST days).
/// For today, the timeline ends at [now].
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.entries,
    required this.now,
    this.pixelsPerMinute = defaultPixelsPerMinute,
  });

  static const double defaultPixelsPerMinute = 1.5;
  static const double _timeGutter = 52;
  static const double _barWidth = 14;
  static const double _labelGap = 12;

  /// Minimum block heights before a label (name / name + times) is drawn.
  static const double _nameOnlyHeight = 18;
  static const double _fullLabelHeight = 38;

  final TimeRange day;
  final List<DayEntry> entries;
  final DateTime now;
  final double pixelsPerMinute;

  /// Where the drawn part of the day ends: day end, or now for today.
  static DateTime visibleEnd(TimeRange day, DateTime now) =>
      day.contains(now) ? now : day.end;

  /// Height of the timeline for [day] (needed for scroll offsets).
  static double heightFor(
    TimeRange day,
    DateTime now, {
    double pixelsPerMinute = defaultPixelsPerMinute,
  }) =>
      visibleEnd(day, now).difference(day.start).inSeconds /
      60 *
      pixelsPerMinute;

  double _y(DateTime t) =>
      t.difference(day.start).inSeconds / 60 * pixelsPerMinute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final end = visibleEnd(day, now);
    final height = heightFor(day, now, pixelsPerMinute: pixelsPerMinute);

    // Hour marks from calendar fields, so DST days get the right labels.
    final hours = <DateTime>[];
    for (var h = 0; ; h++) {
      final t = DateTime(day.start.year, day.start.month, day.start.day, h);
      if (!t.isBefore(end) || !day.contains(t)) break;
      if (hours.isEmpty || t.isAfter(hours.last)) hours.add(t);
    }

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final h in hours) ...[
            Positioned(
              left: _timeGutter,
              right: 0,
              top: _y(h),
              child: Divider(height: 1, color: scheme.outlineVariant),
            ),
            Positioned(
              left: 0,
              width: _timeGutter - 8,
              top: (_y(h) - 7).clamp(0, double.infinity),
              child: Text(
                formatTimeOfDay(h),
                textAlign: TextAlign.right,
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          // The line itself.
          Positioned(
            left: _timeGutter + _barWidth / 2 - 1,
            width: 2,
            top: 0,
            bottom: 0,
            child: ColoredBox(color: scheme.outlineVariant),
          ),
          for (final e in entries) ..._entry(context, e),
        ],
      ),
    );
  }

  List<Widget> _entry(BuildContext context, DayEntry e) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final endAt = e.end ?? now;
    final top = _y(e.start);
    final blockHeight = (_y(endAt) - top).clamp(1.0, double.infinity);
    final running = e.end == null;
    final endLabel = running
        ? 'now'
        : endAt.isAtSameMomentAs(day.end)
        ? '24:00'
        : formatTimeOfDay(endAt);

    return [
      Positioned(
        key: ValueKey('timeline-block-${e.entry.id}'),
        left: _timeGutter,
        width: _barWidth,
        top: top,
        height: blockHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(e.activity.color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      if (blockHeight >= _nameOnlyHeight)
        Positioned(
          left: _timeGutter + _barWidth + _labelGap,
          right: 8,
          top: top + 2,
          height: blockHeight - 2,
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: running ? scheme.primary : null,
                  ),
                ),
                if (blockHeight >= _fullLabelHeight)
                  Text(
                    '${formatTimeOfDay(e.start)} – $endLabel · '
                    '${formatTotal(e.durationAt(now))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}
