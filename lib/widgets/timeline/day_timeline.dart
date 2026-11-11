import 'package:flutter/material.dart';

import '../../services/history/history_service.dart';
import '../../services/tracking/time_range.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import 'timeline_layout.dart';

/// Vertical timeline of one local day. Height follows time at
/// [pixelsPerMinute]; every entry is drawn and labelled, short ones get a
/// minimum height (see [TimelineLayout]). For today the timeline ends at [now].
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.entries,
    required this.now,
  });

  /// 240 px per hour: detail over overview; scroll for earlier hours.
  static const double pixelsPerMinute = 4;

  /// One label line plus padding.
  static const double minBlockHeight = 30;

  /// Blocks at least this tall show name and times on separate lines.
  static const double _twoLineHeight = 48;
  static const double _timeGutter = 52;

  final TimeRange day;
  final List<DayEntry> entries;
  final DateTime now;

  /// Where the drawn part of the day ends: day end, or now for today.
  static DateTime visibleEnd(TimeRange day, DateTime now) =>
      day.contains(now) ? now : day.end;

  static TimelineLayout layoutFor(
    TimeRange day,
    List<DayEntry> entries,
    DateTime now,
  ) => TimelineLayout.compute(
    day: day,
    entries: entries,
    end: visibleEnd(day, now),
    now: now,
    pixelsPerMinute: pixelsPerMinute,
    minBlockHeight: minBlockHeight,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final end = visibleEnd(day, now);
    final layout = layoutFor(day, entries, now);

    // Hour marks from calendar fields, so DST days get the right labels.
    final hours = <DateTime>[];
    for (var h = 0; ; h++) {
      final t = DateTime(day.start.year, day.start.month, day.start.day, h);
      if (!t.isBefore(end) || !day.contains(t)) break;
      if (hours.isEmpty || t.isAfter(hours.last)) hours.add(t);
    }

    return SizedBox(
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final block in layout.blocks) _block(context, block),
          for (final h in hours) ...[
            Positioned(
              left: _timeGutter - 6,
              width: 6,
              top: layout.yOf(h),
              child: Divider(height: 1, color: scheme.outline),
            ),
            Positioned(
              left: 0,
              width: _timeGutter - 10,
              top: (layout.yOf(h) - 7).clamp(0, double.infinity),
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
        ],
      ),
    );
  }

  Widget _block(BuildContext context, TimelineBlock block) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = block.item;
    final color = Color(e.activity.color);
    final endAt = e.end ?? now;
    final running = e.end == null;
    final endLabel = running
        ? 'now'
        : endAt.isAtSameMomentAs(day.end)
        ? '24:00'
        : formatTimeOfDay(endAt);
    final times =
        '${formatTimeOfDay(e.start)} – $endLabel · '
        '${formatEntryDuration(e.durationAt(now))}';
    final name = Text(
      e.activity.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.titleSmall?.copyWith(color: running ? scheme.primary : null),
    );
    final timesText = Text(
      times,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Positioned(
      key: ValueKey('timeline-block-${e.entry.id}'),
      left: _timeGutter,
      right: 8,
      top: block.top,
      height: block.height,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            border: Border(left: BorderSide(color: color, width: 6)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: block.height >= _twoLineHeight
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, timesText],
                  )
                : Row(
                    children: [
                      Flexible(child: name),
                      const SizedBox(width: 8),
                      Flexible(child: timesText),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
