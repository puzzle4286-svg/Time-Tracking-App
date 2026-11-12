import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';
import '../../services/goals/goal_progress.dart';
import '../../util/duration_format.dart';

/// End of the bar's scale: 25 % beyond the largest target.
Duration linearScaleEnd(GoalProgress p) {
  final target = p.maximum ?? p.minimum!;
  return Duration(microseconds: (target.inMicroseconds * 1.25).round());
}

/// Position of [d] on a linear scale from 0 to [end] (0–1, clamped).
double linearFraction(Duration d, Duration end) {
  if (end <= Duration.zero) return 0;
  return (d.inMicroseconds / end.inMicroseconds).clamp(0.0, 1.0);
}

/// Short duration label for marks: `1h`, `1h 30m`, `45m`.
String shortDuration(Duration d) {
  final m = d.inMinutes;
  if (m % 60 == 0 && m >= 60) return '${m ~/ 60}h';
  return formatTotal(d);
}

/// Vivid red for time beyond a goal's maximum; the theme's error colour is
/// too pale for this on dark backgrounds.
const goalOverColor = Color(0xFFFF1744);

/// One goal's progress (D47): a linear bar from 0 to a bit beyond the
/// largest target. Between minimum and maximum the bar is tinted green,
/// beyond the maximum red; the targets have labelled marks. The fill uses
/// the activity's [color], and turns red past the maximum.
class GoalBar extends StatelessWidget {
  const GoalBar({super.key, required this.progress, required this.color});

  final GoalProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZonesPainter(
          progress,
          _GoalColors(theme.colorScheme, color),
          neon: Neon.of(context),
          theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _GoalColors {
  _GoalColors(ColorScheme scheme, this.fill)
    : track = scheme.surfaceContainerHighest,
      ok = Colors.green.withValues(alpha: 0.30),
      overZone = goalOverColor.withValues(alpha: 0.30),
      over = goalOverColor,
      mark = scheme.onSurface;

  final Color fill;
  final Color track;
  final Color ok;
  final Color overZone;
  final Color over;
  final Color mark;
}

void _label(
  Canvas canvas,
  String text,
  TextStyle style,
  double x,
  double y,
  double width,
) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final left = (x - tp.width / 2)
      .clamp(0.0, math.max(0.0, width - tp.width))
      .toDouble();
  tp.paint(canvas, Offset(left, y));
}

/// Linear bar with tinted zones and labelled marks.
class _ZonesPainter extends CustomPainter {
  _ZonesPainter(this.p, this.c, this.labelStyle, {this.neon = false});

  final GoalProgress p;
  final _GoalColors c;
  final TextStyle labelStyle;

  /// Paints a blurred copy of the fill under the bar (D48).
  final bool neon;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 12.0;
    final w = size.width;
    final end = linearScaleEnd(p);
    double x(Duration d) => linearFraction(d, end) * w;
    final bar = RRect.fromLTRBR(0, 2, w, 2 + h, const Radius.circular(6));
    final t = x(p.tracked);
    final maxX = p.maximum == null ? null : x(p.maximum!);
    final within = maxX == null ? t : math.min(t, maxX);
    // Outside the clip, so the glow spills around the bar. Not for fills
    // shorter than the bar is tall: their glow would be a blob at the start.
    if (neon && t > h) {
      final glow = Paint()..maskFilter = Neon.painterGlow;
      canvas.drawRRect(
        RRect.fromLTRBR(0, 2, within, 2 + h, const Radius.circular(6)),
        glow..color = c.fill.withValues(alpha: 0.8),
      );
      if (maxX != null && t > maxX) {
        canvas.drawRect(
          Rect.fromLTRB(maxX, 2, t, 2 + h),
          glow..color = c.over.withValues(alpha: 0.9),
        );
      }
    }
    canvas
      ..drawRRect(bar, Paint()..color = c.track)
      ..save()
      ..clipRRect(bar);
    // Zones: between the targets is "good", beyond the maximum is "over".
    final minX = p.minimum == null ? null : x(p.minimum!);
    if (minX != null) {
      canvas.drawRect(
        Rect.fromLTRB(minX, 2, maxX ?? w, 2 + h),
        Paint()..color = c.ok,
      );
    }
    if (maxX != null) {
      canvas.drawRect(
        Rect.fromLTRB(maxX, 2, w, 2 + h),
        Paint()..color = c.overZone,
      );
    }
    // Fill, inset so the zone tint stays visible as a frame.
    final fillRect = RRect.fromLTRBR(0, 4, within, h, const Radius.circular(4));
    canvas.drawRRect(fillRect, Paint()..color = c.fill);
    if (maxX != null && t > maxX) {
      canvas.drawRect(Rect.fromLTRB(maxX, 4, t, h), Paint()..color = c.over);
    }
    canvas.restore();
    for (final (target, color) in [(p.minimum, c.mark), (p.maximum, c.over)]) {
      if (target == null) continue;
      final mx = x(target).clamp(1.0, w - 1);
      canvas.drawLine(
        Offset(mx, 0),
        Offset(mx, h + 4),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _label(canvas, shortDuration(target), labelStyle, mx, h + 5, w);
    }
  }

  @override
  bool shouldRepaint(_ZonesPainter old) =>
      old.p.tracked != p.tracked || old.c.fill != c.fill || old.neon != neon;
}
