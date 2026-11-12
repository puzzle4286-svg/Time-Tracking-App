import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/goal.dart';
import '../../services/goals/goal_progress.dart';
import '../../services/goals/goal_service.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../widgets/goals/goal_card.dart';
import '../../widgets/goals/goal_editor_page.dart';

/// The goals of one activity with their current progress.
class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.activity,
    required this.goals,
    required this.tracking,
    required this.clock,
  });

  final Activity activity;
  final GoalService goals;

  /// Listened to: progress changes when tracking does.
  final TrackingService tracking;
  final Clock clock;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<GoalProgress>? _items;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.goals.addListener(_load);
    widget.tracking.addListener(_load);
    // Progress of a running activity grows; refresh periodically.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _load();
  }

  @override
  void dispose() {
    widget.goals.removeListener(_load);
    widget.tracking.removeListener(_load);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final goals = await widget.goals.goalsFor(widget.activity.id);
    final items = [for (final g in goals) await widget.goals.progress(g)];
    if (mounted) setState(() => _items = items);
  }

  Future<void> _edit([Goal? existing]) async {
    final result = await Navigator.of(context).push<GoalEditResult>(
      MaterialPageRoute(
        builder: (_) => GoalEditorPage(
          activityName: widget.activity.name,
          now: widget.clock.now(),
          existing: existing,
        ),
      ),
    );
    if (result == null) return;
    switch (result) {
      case SaveGoal(:final draft):
        if (existing == null) {
          await widget.goals.create(widget.activity.id, draft);
        } else {
          await widget.goals.update(existing.id, draft);
        }
      case DeleteGoal():
        await widget.goals.delete(existing!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text('Goals · ${widget.activity.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text('No goals yet.'))
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                for (final p in items)
                  GoalCard(progress: p, onTap: () => _edit(p.goal)),
              ],
            ),
    );
  }
}
