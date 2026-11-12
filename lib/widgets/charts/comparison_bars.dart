import 'package:flutter/material.dart';

import '../../services/analytics/comparison.dart';
import '../../util/duration_format.dart';

/// Horizontal paired bars per activity: the selected period (solid) above
/// the previous period (faded), on a shared scale.
class ComparisonBars extends StatelessWidget {
  const ComparisonBars({
    super.key,
    required this.rows,
    required this.currentLabel,
    required this.previousLabel,
  });

  final List<ComparisonRow> rows;
  final String currentLabel;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final max = rows.fold<Duration>(
      Duration.zero,
      (m, r) => [m, r.current, r.previous].reduce((a, b) => a > b ? a : b),
    );

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          children: [
            legend(scheme.onSurface, currentLabel),
            legend(scheme.onSurface.withValues(alpha: 0.35), previousLabel),
          ],
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.activity.name, style: text.titleSmall),
                    ),
                    Text(
                      _difference(r),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Bar(
                  key: ValueKey('bar-current-${r.activity.id}'),
                  value: r.current,
                  max: max,
                  color: Color(r.activity.color),
                ),
                const SizedBox(height: 3),
                _Bar(
                  key: ValueKey('bar-previous-${r.activity.id}'),
                  value: r.previous,
                  max: max,
                  color: Color(r.activity.color).withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _difference(ComparisonRow r) {
    final d = r.difference;
    if (d == Duration.zero) return 'no change';
    final sign = d.isNegative ? '−' : '+';
    return '$sign${formatTotal(d.abs())}';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
  });

  final Duration value;
  final Duration max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = max == Duration.zero
        ? 0.0
        : value.inMicroseconds / max.inMicroseconds;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: c.maxWidth * fraction,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            formatTotal(value),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
