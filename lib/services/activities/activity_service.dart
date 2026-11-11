import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/activity_colors.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import '../tracking/entry_normalization.dart';
import '../tracking/tracking_service.dart';

/// What happens to an activity's past entries when it is deleted.
sealed class HistoryChoice {
  const HistoryChoice();
}

/// Keep the entries under a new name (the activity row is renamed).
final class KeepUnderName extends HistoryChoice {
  const KeepUnderName(this.name);
  final String name;
}

/// Reassign the entries to another live activity.
final class MoveToActivity extends HistoryChoice {
  const MoveToActivity(this.activityId);
  final int activityId;
}

/// Reassign the entries to the system "Unavailable" activity.
final class MarkUnavailable extends HistoryChoice {
  const MarkUnavailable();
}

/// The eight grid activities and the operations that change them.
class ActivityService extends ChangeNotifier {
  ActivityService(this._db, this._clock, this._tracking);

  static const int maxNameLength = 30;

  final Database _db;
  final Clock _clock;

  /// Needed to hand over the active state when the active activity is
  /// deleted, and to refresh the current session after changes.
  final TrackingService _tracking;

  List<Activity> _live = const [];

  /// Live activities ordered by position.
  List<Activity> get live => _live;

  Activity? atPosition(int position) =>
      _live.where((a) => a.position == position).firstOrNull;

  Activity? byId(int id) => _live.where((a) => a.id == id).firstOrNull;

  /// First colour not used by another live activity (or the first colour).
  int suggestColor() {
    final used = _live.map((a) => a.color).toSet();
    return activityColors.where((c) => !used.contains(c)).firstOrNull ??
        activityColors.first;
  }

  /// Returns an error message, or null if [name] is acceptable.
  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a name';
    if (trimmed.length > maxNameLength) {
      return 'At most $maxNameLength characters';
    }
    return null;
  }

  Future<void> load() async {
    _live = await ActivityRepository(_db).liveActivities();
    notifyListeners();
  }

  /// Creates a new activity in an empty grid [position].
  Future<Activity> create({
    required int position,
    required String name,
    required int color,
  }) async {
    _checkName(name);
    if (position < 1 || position > Activity.gridSize) {
      throw ArgumentError.value(position, 'position', 'Must be 1–8');
    }
    if (atPosition(position) != null) {
      throw StateError('Position $position is already in use.');
    }
    final id = await ActivityRepository(_db).insert(
      name: name.trim(),
      color: color,
      position: position,
      createdAt: _clock.now(),
    );
    await load();
    return byId(id)!;
  }

  /// Renames / recolours an activity. History follows automatically because
  /// entries reference the activity by id.
  Future<void> update(
    int id, {
    required String name,
    required int color,
  }) async {
    _checkName(name);
    await ActivityRepository(_db).update(id, name: name.trim(), color: color);
    await load();
  }

  void _checkName(String name) {
    final error = validateName(name);
    if (error != null) throw ArgumentError.value(name, 'name', error);
  }

  /// Number of time entries recorded for [activityId].
  Future<int> entryCount(int activityId) =>
      TimeEntryRepository(_db).countForActivity(activityId);

  /// Deletes a grid activity without losing history.
  ///
  /// If it has entries, [history] says what happens to them. If it is the
  /// active activity, [newActiveId] must name the activity that runs from now
  /// on (exactly one activity is always active). Everything is validated
  /// before anything is written.
  Future<void> delete(
    int id, {
    HistoryChoice? history,
    int? newActiveId,
  }) async {
    final activity = byId(id);
    if (activity == null) throw StateError('Activity $id is not live.');
    final isActive = _tracking.current.activity.id == id;
    final count = await entryCount(id);

    if (isActive) {
      if (newActiveId == null ||
          newActiveId == id ||
          byId(newActiveId) == null) {
        throw ArgumentError.value(
          newActiveId,
          'newActiveId',
          'Choose another activity to run from now on',
        );
      }
    }
    if (count > 0) {
      switch (history) {
        case null:
          throw ArgumentError('Choose what happens to the past entries');
        case KeepUnderName(:final name):
          _checkName(name);
        case MoveToActivity(:final activityId):
          if (activityId == id || byId(activityId) == null) {
            throw ArgumentError.value(
              activityId,
              'activityId',
              'Not another live activity',
            );
          }
        case MarkUnavailable():
          break;
      }
    }

    // Hand over the active state first (its own atomic transaction), so
    // there is never a moment without an active activity.
    if (isActive) await _tracking.switchTo(newActiveId!);

    final now = _clock.now();
    await _db.transaction((txn) async {
      final activities = ActivityRepository(txn);
      final entries = TimeEntryRepository(txn);
      switch (count > 0 ? history : null) {
        case KeepUnderName(:final name):
          await activities.softDelete(id, now, rename: name.trim());
        case MoveToActivity(:final activityId):
          await entries.reassignActivity(id, activityId);
          await activities.softDelete(id, now);
        case MarkUnavailable():
          final unavailable = await activities.systemActivity();
          await entries.reassignActivity(id, unavailable!.id);
          await activities.softDelete(id, now);
        case null:
          await activities.softDelete(id, now);
      }
      // Moved entries may now sit next to entries of the same activity.
      if (history is MoveToActivity || history is MarkUnavailable) {
        final first = await entries.earliestStart();
        if (first != null) {
          await mergeSameActivityNeighbours(
            entries,
            first,
            now.add(const Duration(days: 1)),
          );
        }
      }
    });
    await load();
    await _tracking.reconcile();
  }
}
