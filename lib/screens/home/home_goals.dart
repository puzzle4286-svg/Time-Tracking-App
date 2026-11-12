import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';
import '../../services/activities/activity_service.dart';
import '../../services/goals/goal_progress.dart';
import '../../services/goals/goal_service.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import '../../widgets/common/activity_dot.dart';
import '../../widgets/goals/goal_bars.dart';
import '../../widgets/goals/goal_text.dart';

/// Progress of the running activity's enabled goals on the main screen
/// (read-only; goals are edited through a tile's long press). Reloads when tracking, activities
/// or goals change, and every [refresh] so the running activity's bar grows.
class HomeGoals extends StatefulWidget {
  const HomeGoals({
    super.key,
    required this.goals,
    required this.tracking,
    required this.activities,
  });

  final GoalService goals;
  final TrackingService tracking;
  final ActivityService activities;

  static const refresh = Duration(seconds: 15);

  @override
  State<HomeGoals> createState() => _HomeGoalsState();
}

class _HomeGoalsState extends State<HomeGoals> {
  late final Listenable _changes = Listenable.merge([
    widget.goals,
    widget.tracking,
    widget.activities,
  ]);
  List<GoalProgress> _items = const [];
  Timer? _ticker;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _changes.addListener(_load);
    _ticker = Timer.periodic(HomeGoals.refresh, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes.removeListener(_load);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    // Only the running activity's goals (none while on Default).
    final items = await widget.goals.gridProgress(
      activityId: widget.tracking.current.activity.id,
    );
    // Only the newest load may win (loads can overlap).
    if (mounted && generation == _generation) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      key: const Key('home-goals'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _GoalRow(progress: _items[i], activities: widget.activities),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.progress, required this.activities});

  final GoalProgress progress;
  final ActivityService activities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final g = progress.goal;
    final activity = activities.byId(g.activityId);
    final color = Color(activity?.color ?? scheme.primary.toARGB32());
    final over = progress.maximumExceeded;
    final targets = describeGoalTargets(g, formatTotal);

    return Semantics(
      container: true,
      label:
          '${g.name ?? 'Goal'}: ${formatTotal(progress.tracked)}, $targets, '
          'period ends ${formatMoment(progress.period.end)}',
      excludeSemantics: true,
      child: Column(
        key: ValueKey('home-goal-${g.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ActivityDot(color: color, size: 10),
              const SizedBox(width: 8),
              // The goal's name if it has one; the activity is the one
              // shown in the header, so its name is not repeated.
              Expanded(
                child: Text(
                  g.name ?? '',
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatTotal(progress.tracked),
                key: ValueKey('home-goal-tracked-${g.id}'),
                style: text.titleSmall?.copyWith(
                  color: over ? goalOverColor : null,
                  fontWeight: FontWeight.w600,
                  shadows: over ? Neon.textGlow(context, goalOverColor) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GoalBar(
            key: ValueKey('goal-bar-${g.id}'),
            progress: progress,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            '$targets · until ${formatMoment(progress.period.end)}',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
