import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/goal.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/goal_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import 'goal_period.dart';
import 'goal_progress.dart';

/// The values of a goal being created or edited.
class GoalDraft {
  const GoalDraft({
    this.name,
    required this.unit,
    required this.length,
    required this.anchor,
    this.minimum,
    this.maximum,
    this.enabled = true,
  });

  final String? name;
  final GoalUnit unit;
  final int length;
  final GoalAnchor anchor;
  final Duration? minimum;
  final Duration? maximum;
  final bool enabled;

  /// Returns an error message, or null if the draft is valid.
  String? validate() {
    if (length < 1 || length > 999) return 'Period length must be 1–999';
    if ((name?.trim().length ?? 0) > GoalService.maxNameLength) {
      return 'Name: at most ${GoalService.maxNameLength} characters';
    }
    if (minimum == null && maximum == null) {
      return 'Set a minimum, a maximum, or both';
    }
    if ((minimum != null && minimum! <= Duration.zero) ||
        (maximum != null && maximum! <= Duration.zero)) {
      return 'Targets must be longer than zero';
    }
    if (minimum != null && maximum != null && minimum! > maximum!) {
      return 'The minimum cannot be larger than the maximum';
    }
    return null;
  }
}

/// Goals of grid activities and their progress. Progress is always derived
/// from recorded entries; nothing about it is stored.
class GoalService extends ChangeNotifier {
  GoalService(this._db, this._clock);

  static const int maxNameLength = 40;

  final Database _db;
  final Clock _clock;

  Future<List<Goal>> goalsFor(int activityId) =>
      GoalRepository(_db).forActivity(activityId);

  Future<Goal> create(int activityId, GoalDraft draft) async {
    _check(draft);
    final activity = await ActivityRepository(_db).byId(activityId);
    if (activity == null || activity.isDeleted || activity.position == null) {
      throw ArgumentError.value(
        activityId,
        'activityId',
        'Not a grid activity',
      );
    }
    final repo = GoalRepository(_db);
    final id = await repo.insert(
      activityId: activityId,
      name: _name(draft),
      unit: draft.unit,
      length: draft.length,
      anchor: draft.anchor,
      minimum: draft.minimum,
      maximum: draft.maximum,
      enabled: draft.enabled,
      createdAt: _clock.now(),
    );
    notifyListeners();
    return (await repo.byId(id))!;
  }

  Future<void> update(int goalId, GoalDraft draft) async {
    _check(draft);
    await GoalRepository(_db).update(
      goalId,
      name: _name(draft),
      unit: draft.unit,
      length: draft.length,
      anchor: draft.anchor,
      minimum: draft.minimum,
      maximum: draft.maximum,
      enabled: draft.enabled,
    );
    notifyListeners();
  }

  Future<void> delete(int goalId) async {
    await GoalRepository(_db).delete(goalId);
    notifyListeners();
  }

  /// Progress of [goal] in its current period.
  Future<GoalProgress> progress(Goal goal) async {
    final now = _clock.now();
    final period = currentGoalPeriod(goal, now);
    final entries = await TimeEntryRepository(
      _db,
    ).overlapping(period.start, period.end);
    return goalProgress(goal, entries, now);
  }

  static String? _name(GoalDraft d) {
    final n = d.name?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  static void _check(GoalDraft d) {
    final error = d.validate();
    if (error != null) throw ArgumentError(error);
  }
}
