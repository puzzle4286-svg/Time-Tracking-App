import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';

/// A donut chart of [values] (any positive numbers) in [colors], with
/// [center] drawn in the hole. Drawn directly; no chart package.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.center,
    this.size = 200,
    this.thickness = 28,
  });

  final List<double> values;
  final List<Color> colors;
  final Widget? center;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DonutPainter(
          values: values,
          colors: colors,
          thickness: thickness,
          track: Theme.of(context).colorScheme.surfaceContainerHighest,
          neon: Neon.of(context),
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.thickness,
    required this.track,
    this.neon = false,
  });

  final List<double> values;
  final List<Color> colors;
  final double thickness;
  final Color track;

  /// Draws a blurred copy of each segment underneath (D48).
  final bool neon;

  /// Visual gap between segments, in radians.
  static const _gap = 0.025;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - thickness) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
      return;
    }
    final gap = values.where((v) => v > 0).length > 1 ? _gap : 0.0;
    // Segments as (start, sweep, colour), after the gaps.
    final arcs = <(double, double, Color)>[];
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final drawn = sweep - gap > 0.002 ? sweep - gap : sweep;
      arcs.add((start, drawn, colors[i]));
      start += sweep;
    }
    // All glows first, so no glow covers a neighbouring segment.
    if (neon) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..maskFilter = Neon.painterGlow;
      for (final (from, sweep, color) in arcs) {
        canvas.drawArc(
          rect,
          from,
          sweep,
          false,
          glow..color = color.withValues(alpha: 0.7),
        );
      }
    }
    for (final (from, sweep, color) in arcs) {
      canvas.drawArc(rect, from, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.thickness != thickness ||
      old.track != track ||
      old.neon != neon ||
      !_listEquals(old.values, values) ||
      !_listEquals(old.colors, colors);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
