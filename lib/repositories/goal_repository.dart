import 'package:sqflite/sqflite.dart';

import '../models/goal.dart';
import '../util/timestamps.dart';

/// SQL access for the `goals` table.
class GoalRepository {
  const GoalRepository(this._db);

  final DatabaseExecutor _db;

  Future<List<Goal>> forActivity(int activityId) async {
    final rows = await _db.query(
      'goals',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'id',
    );
    return rows.map(Goal.fromRow).toList();
  }

  /// Enabled goals of activities currently on the grid, in grid order;
  /// only those of [activityId] if given.
  Future<List<Goal>> enabledOnGrid({int? activityId}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT g.* FROM goals g JOIN activities a ON a.id = g.activity_id
      WHERE g.enabled = 1 AND a.deleted_at IS NULL AND a.position IS NOT NULL
        ${activityId == null ? '' : 'AND g.activity_id = ?'}
      ORDER BY a.position, g.id
    ''',
      [?activityId],
    );
    return rows.map(Goal.fromRow).toList();
  }

  Future<Goal?> byId(int id) async {
    final rows = await _db.query('goals', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Goal.fromRow(rows.single);
  }

  Future<int> insert({
    required int activityId,
    required String? name,
    required GoalUnit unit,
    required int length,
    required GoalAnchor anchor,
    required Duration? minimum,
    required Duration? maximum,
    required bool enabled,
    required DateTime createdAt,
  }) => _db.insert('goals', {
    'activity_id': activityId,
    'created_at': toStoredTimestamp(createdAt),
    ..._fields(name, unit, length, anchor, minimum, maximum, enabled),
  });

  Future<void> update(
    int id, {
    required String? name,
    required GoalUnit unit,
    required int length,
    required GoalAnchor anchor,
    required Duration? minimum,
    required Duration? maximum,
    required bool enabled,
  }) async {
    final n = await _db.update(
      'goals',
      _fields(name, unit, length, anchor, minimum, maximum, enabled),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n != 1) throw StateError('Goal $id does not exist.');
  }

  Future<void> delete(int id) =>
      _db.delete('goals', where: 'id = ?', whereArgs: [id]);

  static Map<String, Object?> _fields(
    String? name,
    GoalUnit unit,
    int length,
    GoalAnchor anchor,
    Duration? minimum,
    Duration? maximum,
    bool enabled,
  ) => {
    'name': name,
    'period_unit': unit.name,
    'period_length': length,
    'anchor_year': anchor.year,
    'anchor_month': anchor.month,
    'anchor_day': anchor.day,
    'anchor_minute': anchor.minuteOfDay,
    'min_us': minimum?.inMicroseconds,
    'max_us': maximum?.inMicroseconds,
    'enabled': enabled ? 1 : 0,
  };
}
