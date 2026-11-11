import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/activity.dart';
import '../../services/activities/activity_service.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../widgets/activities/activity_editor_sheet.dart';
import '../../widgets/activities/activity_tile.dart';
import 'current_activity_header.dart';

/// Main screen: current activity on top, a compact grid (2 rows × 4
/// columns, positions 1–4 on top) at the bottom, within thumb reach.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.tracking,
    required this.activities,
    required this.clock,
  });

  final TrackingService tracking;
  final ActivityService activities;
  final Clock clock;

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
      ),
    );
  }

  Future<void> _edit(BuildContext context, Activity activity) async {
    final draft = await showActivityEditor(
      context,
      title: 'Edit activity',
      initialName: activity.name,
      initialColor: activity.color,
    );
    if (draft == null || !context.mounted) return;
    await _guard(
      context,
      () =>
          activities.update(activity.id, name: draft.name, color: draft.color),
    );
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

        return SafeArea(
          child: Column(
            children: [
              CurrentActivityHeader(
                tracking: tracking,
                activity: active,
                clock: clock,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
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
                ),
              ),
            ],
          ),
        );
      },
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
