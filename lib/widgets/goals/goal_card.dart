import 'package:flutter/material.dart';

import '../../services/goals/goal_progress.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import 'goal_text.dart';

/// A goal with its progress in the current period.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.progress, required this.onTap});

  final GoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = progress.goal;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = g.name ?? describeGoalPeriod(g);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: g.enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: text.titleMedium)),
                    if (!g.enabled) Text('Paused', style: text.labelMedium),
                  ],
                ),
                if (g.name != null)
                  Text(describeGoalPeriod(g), style: text.bodySmall),
                Text(
                  'This period: ${formatMoment(progress.period.start)} – '
                  '${formatMoment(progress.period.end)}',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (progress.minimum != null) ...[
                  const SizedBox(height: 12),
                  _Bar(
                    key: const Key('goal-min'),
                    label: progress.minimumReached
                        ? 'Minimum reached'
                        : 'Minimum',
                    value: progress.minimumFraction!,
                    color: progress.minimumReached
                        ? Colors.green
                        : scheme.primary,
                    detail:
                        '${formatTotal(progress.tracked)} of '
                        '${formatTotal(progress.minimum!)} · '
                        '${(progress.minimumFraction! * 100).floor()}%'
                        '${progress.minimumReached ? '' : ' · ${formatTotal(progress.untilMinimum!)} to go'}',
                  ),
                ],
                if (progress.maximum != null) ...[
                  const SizedBox(height: 12),
                  _Bar(
                    key: const Key('goal-max'),
                    label: progress.maximumExceeded
                        ? 'Maximum exceeded'
                        : 'Maximum',
                    value: progress.maximumFraction!,
                    color: progress.maximumExceeded
                        ? scheme.error
                        : scheme.tertiary,
                    detail: progress.maximumExceeded
                        ? '${formatTotal(progress.tracked)} of '
                              '${formatTotal(progress.maximum!)} · over by '
                              '${formatTotal(progress.overMaximum!)}'
                        : '${formatTotal(progress.tracked)} of '
                              '${formatTotal(progress.maximum!)} used · '
                              '${formatTotal(progress.remainingAllowance!)} left',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.detail,
  });

  final String label;
  final double value;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelLarge?.copyWith(color: color)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 8,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: text.bodySmall),
      ],
    );
  }
}
