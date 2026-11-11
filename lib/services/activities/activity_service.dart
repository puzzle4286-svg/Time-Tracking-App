import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/activity_colors.dart';
import '../../repositories/activity_repository.dart';
import '../../util/clock.dart';

/// The eight grid activities and the operations that change them.
class ActivityService extends ChangeNotifier {
  ActivityService(this._db, this._clock);

  static const int maxNameLength = 30;

  final Database _db;
  final Clock _clock;

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
}
