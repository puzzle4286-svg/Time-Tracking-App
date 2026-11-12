import 'package:sqflite/sqflite.dart';

import '../models/activity.dart';
import '../util/timestamps.dart';

/// SQL access for the `activities` table.
///
/// Takes a [DatabaseExecutor] so it works both on the database and inside a
/// transaction.
class ActivityRepository {
  const ActivityRepository(this._db);

  final DatabaseExecutor _db;

  /// Activities currently placed in the grid, ordered by position.
  Future<List<Activity>> liveActivities() async {
    final rows = await _db.query(
      'activities',
      where: 'deleted_at IS NULL AND position IS NOT NULL',
      orderBy: 'position',
    );
    return rows.map(Activity.fromRow).toList();
  }

  /// Every activity, including deleted and system ones, keyed by id, so
  /// historical entries can always be shown with a name and colour.
  Future<Map<int, Activity>> allById() async {
    final rows = await _db.query('activities');
    return {for (final a in rows.map(Activity.fromRow)) a.id: a};
  }

  Future<Activity?> byId(int id) async {
    final rows = await _db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Activity.fromRow(rows.single);
  }

  Future<Activity?> withRole(SystemRole role) async {
    final rows = await _db.query(
      'activities',
      where: 'role = ?',
      whereArgs: [role.value],
    );
    return rows.isEmpty ? null : Activity.fromRow(rows.single);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM activities');
    return rows.single['n']! as int;
  }

  Future<int> insert({
    required String name,
    required int color,
    required int? position,
    required DateTime createdAt,
    SystemRole? role,
    String? icon,
  }) {
    return _db.insert('activities', {
      'name': name,
      'color': color,
      'position': position,
      'is_system': role == null ? 0 : 1,
      'role': role?.value,
      'icon': icon,
      'created_at': toStoredTimestamp(createdAt),
    });
  }

  /// Updates a live activity's name, colour and icon (null clears it).
  Future<void> update(
    int id, {
    required String name,
    required int color,
    String? icon,
  }) async {
    final updated = await _db.update(
      'activities',
      {'name': name, 'color': color, 'icon': icon},
      where: 'id = ? AND deleted_at IS NULL AND is_system = 0',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Activity $id is not editable.');
  }

  /// Puts a live grid activity at [position] (null takes it off the grid
  /// briefly, so two activities can swap without breaking the unique
  /// position index).
  Future<void> setPosition(int id, int? position) async {
    final updated = await _db.update(
      'activities',
      {'position': position},
      where: 'id = ? AND deleted_at IS NULL AND is_system = 0',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Activity $id cannot be moved.');
  }

  /// Removes an activity from the grid but keeps its row, so history that
  /// still references it stays readable. Optionally renames it.
  Future<void> softDelete(int id, DateTime at, {String? rename}) async {
    final updated = await _db.update(
      'activities',
      {'deleted_at': toStoredTimestamp(at), 'position': null, 'name': ?rename},
      where: 'id = ? AND deleted_at IS NULL AND is_system = 0',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Activity $id cannot be deleted.');
  }
}
