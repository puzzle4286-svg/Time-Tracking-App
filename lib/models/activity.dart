import '../util/timestamps.dart';

/// One of the user's activities.
///
/// Live activities occupy one of the eight grid [position]s (1–8). Deleted
/// activities keep their row (with [deletedAt] set and no position) so that
/// historical time entries stay readable. The single [isSystem] activity
/// ("Unavailable") holds history whose activity was deleted without a
/// replacement; it is never shown in the grid.
class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.isSystem,
    required this.createdAt,
    required this.deletedAt,
  });

  static const int gridRows = 2;
  static const int gridColumns = 4;
  static const int gridSize = gridRows * gridColumns;

  final int id;
  final String name;

  /// ARGB colour value.
  final int color;

  /// 1–8 while live in the grid, otherwise null.
  final int? position;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Activity.fromRow(Map<String, Object?> row) => Activity(
    id: row['id']! as int,
    name: row['name']! as String,
    color: row['color']! as int,
    position: row['position'] as int?,
    isSystem: row['is_system'] == 1,
    createdAt: fromStoredTimestamp(row['created_at']! as int),
    deletedAt: fromStoredTimestampOrNull(row['deleted_at']),
  );
}
