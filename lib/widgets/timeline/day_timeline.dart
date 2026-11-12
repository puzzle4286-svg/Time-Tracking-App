import 'package:flutter/material.dart';

import '../../services/history/history_service.dart';
import '../../services/tracking/time_range.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import '../entries/entry_strip.dart';
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
    this.onEntryTap,
  });

  /// 240 px per hour: detail over overview; scroll for earlier hours.
  static const double pixelsPerMinute = 4;

  /// One label line plus padding.
  static const double minBlockHeight = 30;

  /// Blocks at least this tall show name and times on separate lines, if
  /// both lines also fit at the current text size (see [_twoLineFits]).
  static const double _twoLineHeight = 48;

  /// Vertical space around the label: the strip's padding (4 + 4) and the
  /// 1 px gap below each block.
  static const double _labelChrome = 9;

  /// Whether name and times fit on two lines in [height]. Measured with the
  /// system text scale: on a phone with larger text (e.g. 1.15x) the fixed
  /// threshold alone overflowed by a few pixels.
  static bool _twoLineFits(
    BuildContext context,
    double height,
    TextStyle? nameStyle,
    TextStyle? timesStyle,
  ) {
    if (height < _twoLineHeight) return false;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) {
      final tp = TextPainter(
        text: TextSpan(text: 'Hg', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = tp.height;
      tp.dispose();
      return h;
    }

    return line(nameStyle) + line(timesStyle) + _labelChrome <= height;
  }

  static const double _timeGutter = 52;

  final TimeRange day;
  final List<DayEntry> entries;
  final DateTime now;

  /// Called when an entry is tapped (opens its editor).
  final ValueChanged<DayEntry>? onEntryTap;

  /// Where the drawn part of the day ends: day end, or now for today.
  static DateTime visibleEnd(TimeRange day, DateTime now) =>
      day.contains(now) ? now : day.end;

  /// Every full hour and half hour of [day] before [end], from calendar
  /// fields so DST days get the right marks (a skipped hour has no mark, a
  /// repeated hour is not marked twice).
  static List<({DateTime time, bool isHalfHour})> gridMarks(
    TimeRange day,
    DateTime end,
  ) {
    final marks = <({DateTime time, bool isHalfHour})>[];
    final d = day.start;
    for (var h = 0; h < 26; h++) {
      for (final minute in const [0, 30]) {
        final t = DateTime(d.year, d.month, d.day, h, minute);
        if (!t.isBefore(end) || !day.contains(t)) continue;
        if (marks.isNotEmpty && !t.isAfter(marks.last.time)) continue;
        marks.add((time: t, isHalfHour: minute == 30));
      }
    }
    return marks;
  }

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

    final marks = gridMarks(day, end);
    final hours = [
      for (final m in marks)
        if (!m.isHalfHour) m.time,
    ];

    return SizedBox(
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Hour (solid) and half-hour (dashed) lines, behind the entries.
          Positioned.fill(
            left: _timeGutter - 6,
            child: CustomPaint(
              key: const Key('timeline-grid'),
              painter: _GridPainter(
                lines: [
                  for (final m in marks) (layout.yOf(m.time), m.isHalfHour),
                ],
                hourColor: scheme.outlineVariant,
                halfHourColor: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          for (final block in layout.blocks) _block(context, block),
          for (final h in hours) ...[
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
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onEntryTap == null ? null : () => onEntryTap!(e),
            child: EntryStrip(
              color: color,
              child:
                  _twoLineFits(
                    context,
                    block.height,
                    name.style,
                    timesText.style,
                  )
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
      ),
    );
  }
}

/// Draws full-width horizontal lines: solid for hours, dashed for half hours.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.lines,
    required this.hourColor,
    required this.halfHourColor,
  });

  /// (y, isHalfHour) for each line.
  final List<(double, bool)> lines;
  final Color hourColor;
  final Color halfHourColor;

  static const double _dash = 6;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final hour = Paint()
      ..color = hourColor
      ..strokeWidth = 1;
    final half = Paint()
      ..color = halfHourColor
      ..strokeWidth = 1;
    for (final (y, isHalf) in lines) {
      final dy = y + 0.5; // crisp 1 px line
      if (!isHalf) {
        canvas.drawLine(Offset(0, dy), Offset(size.width, dy), hour);
        continue;
      }
      for (var x = 0.0; x < size.width; x += _dash + _gap) {
        final to = x + _dash > size.width ? size.width : x + _dash;
        canvas.drawLine(Offset(x, dy), Offset(to, dy), half);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hourColor != hourColor ||
      old.halfHourColor != halfHourColor ||
      !_sameLines(old.lines, lines);

  static bool _sameLines(List<(double, bool)> a, List<(double, bool)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
