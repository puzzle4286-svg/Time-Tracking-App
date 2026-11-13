import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/activity.dart';
import '../../repositories/ui_state_store.dart';
import '../../services/activities/activity_service.dart';
import '../../services/goals/goal_service.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../widgets/activities/activity_editor_sheet.dart';
import '../../widgets/activities/activity_guide_sheet.dart';
import '../../widgets/activities/activity_tile.dart';
import '../../widgets/activities/delete_activity_flow.dart';
import '../goals/goals_page.dart';
import 'arrange_grid_page.dart';
import 'current_activity_header.dart';
import 'home_goals.dart';

/// Main screen: current activity on top, a compact grid (2 rows × 4
/// columns, positions 1–4 on top) at the bottom, within thumb reach.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.tracking,
    required this.activities,
    required this.goals,
    required this.clock,
    required this.uiState,
  });

  /// Set once the swipe-up hint has been shown.
  static const guideHintKey = 'home.guideHintShown';

  final TrackingService tracking;
  final ActivityService activities;
  final GoalService goals;
  final Clock clock;
  final UiStateStore uiState;

  /// Compact buttons, so the grid takes little space at the bottom.
  static const double tileHeight = 64;

  Future<void> _select(BuildContext context, Activity activity) async {
    if (activity.id == tracking.current.activity.id) return;
    unawaited(HapticFeedback.selectionClick());
    await _guard(context, () => tracking.switchTo(activity.id));
  }

  Future<void> _setUp(BuildContext context, int position) async {
    final draft = await showActivityEditor(
      context,
      title: 'Set up activity',
      initialName: '',
      initialColor: activities.suggestColor(),
    );
    if (draft == null || !context.mounted) return;
    await _guard(
      context,
      () => activities.create(
        position: position,
        name: draft.name,
        color: draft.color,
        icon: draft.icon,
        description: draft.description,
      ),
    );
    if (context.mounted) _maybeShowGuideHint(context, draft.description);
  }

  Future<void> _edit(BuildContext context, Activity activity) async {
    final draft = await showActivityEditor(
      context,
      title: 'Edit activity',
      initialName: activity.name,
      initialColor: activity.color,
      initialIcon: activity.icon,
      initialDescription: activity.description,
      onGoals: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GoalsPage(
            activity: activity,
            goals: goals,
            tracking: tracking,
            clock: clock,
          ),
        ),
      ),
      onArrange: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArrangeGridPage(activities: activities),
        ),
      ),
      onDelete: () => runDeleteActivityFlow(
        context,
        activity: activity,
        activities: activities,
        tracking: tracking,
      ),
    );
    if (draft == null || !context.mounted) return;
    await _guard(
      context,
      () => activities.update(
        activity.id,
        name: draft.name,
        color: draft.color,
        icon: draft.icon,
        description: draft.description,
      ),
    );
    if (context.mounted) _maybeShowGuideHint(context, draft.description);
  }

  /// Runs [action], reporting failures instead of crashing the UI.
  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not complete that: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tracking, activities]),
      builder: (context, _) {
        final session = tracking.current;
        final activeId = session.activity.id;
        // Prefer the live row so renames show immediately.
        final active = activities.byId(activeId) ?? session.activity;

        final header = CurrentActivityHeader(
          tracking: tracking,
          activity: active,
          clock: clock,
        );
        // The running activity's goals, right under the header (scrolls
        // when there are many).
        final goalList = Align(
          alignment: Alignment.topCenter,
          child: HomeGoals(
            goals: goals,
            tracking: tracking,
            activities: activities,
          ),
        );
        // Swiping up on the grid opens "Which activity?" (what each
        // activity covers); nothing on screen for it (D54).
        final grid = _SwipeUp(
          key: const Key('activity-grid'),
          onSwipeUp: () => _openGuide(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _grid(context, activeId),
          ),
        );

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Held sideways there is not enough height for header,
              // goals and grid stacked: header and goals on the left, the
              // grid on the right, at the bottom within thumb reach (D56).
              if (constraints.maxWidth > constraints.maxHeight) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Scales down rather than overflowing when the
                          // screen is very short.
                          Flexible(
                            flex: 0,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: constraints.maxWidth / 2,
                                child: header,
                              ),
                            ),
                          ),
                          Expanded(child: goalList),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(
                          reverse: true,
                          padding: const EdgeInsets.only(top: 12),
                          child: grid,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  header,
                  Expanded(child: goalList),
                  grid,
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The 2 × 4 activity grid, positions 1–4 on top.
  Widget _grid(BuildContext context, int activeId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < Activity.gridRows; row++)
          SizedBox(
            height: tileHeight + 6,
            child: Row(
              children: [
                for (var col = 0; col < Activity.gridColumns; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _tile(
                        context,
                        row * Activity.gridColumns + col + 1,
                        activeId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _openGuide(BuildContext context) {
    if (activities.live.isEmpty) return;
    unawaited(
      showActivityGuide(
        context,
        activities: activities.live,
        activeId: tracking.current.activity.id,
        onSelect: (a) => _select(context, a),
        onEdit: (a) => _edit(context, a),
      ),
    );
  }

  /// After the first description is saved, says once how to find them.
  void _maybeShowGuideHint(BuildContext context, String description) {
    if (description.trim().isEmpty || uiState.get(guideHintKey) != null) {
      return;
    }
    unawaited(uiState.set(guideHintKey, '1'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Swipe up on the grid to see what each activity covers'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Widget _tile(BuildContext context, int position, int activeId) {
    final activity = activities.atPosition(position);
    return ActivityTile(
      key: Key('activity-tile-$position'),
      activity: activity,
      isActive: activity?.id == activeId,
      onTap: () => activity == null
          ? _setUp(context, position)
          : _select(context, activity),
      onLongPress: () => activity == null
          ? _setUp(context, position)
          : _edit(context, activity),
    );
  }
}

/// Calls [onSwipeUp] for an upward swipe over [child] (a fast flick or a
/// drag of [minDistance]). Taps and long presses still reach the tiles.
class _SwipeUp extends StatefulWidget {
  const _SwipeUp({super.key, required this.onSwipeUp, required this.child});

  static const double minDistance = 48;
  static const double minVelocity = 300;

  final VoidCallback onSwipeUp;
  final Widget child;

  @override
  State<_SwipeUp> createState() => _SwipeUpState();
}

class _SwipeUpState extends State<_SwipeUp> {
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => _dy = 0,
      onVerticalDragUpdate: (d) => _dy += d.delta.dy,
      onVerticalDragEnd: (d) {
        final flick = (d.primaryVelocity ?? 0) <= -_SwipeUp.minVelocity;
        if (flick || _dy <= -_SwipeUp.minDistance) widget.onSwipeUp();
        _dy = 0;
      },
      child: widget.child,
    );
  }
}
