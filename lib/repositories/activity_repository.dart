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

  Future<Activity?> systemActivity() async {
    final rows = await _db.query('activities', where: 'is_system = 1');
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
    bool isSystem = false,
  }) {
    return _db.insert('activities', {
      'name': name,
      'color': color,
      'position': position,
      'is_system': isSystem ? 1 : 0,
      'created_at': toStoredTimestamp(createdAt),
    });
  }

  /// Updates a live activity's name and colour.
  Future<void> update(
    int id, {
    required String name,
    required int color,
  }) async {
    final updated = await _db.update(
      'activities',
      {'name': name, 'color': color},
      where: 'id = ? AND deleted_at IS NULL AND is_system = 0',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Activity $id is not editable.');
  }
}
