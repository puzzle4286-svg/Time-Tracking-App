import '../util/timestamps.dart';

/// Built-in activities that are not on the grid and cannot be edited.
enum SystemRole {
  /// "Default": active on first launch; can take over any time (fill
  /// choices, successor of a deleted activity) but is never on the grid.
  defaultActivity('default'),

  /// "Unavailable": holds history of deleted activities when chosen.
  unavailable('unavailable');

  const SystemRole(this.value);

  /// Stored value in `activities.role`.
  final String value;

  static SystemRole? parse(Object? value) =>
      values.where((r) => r.value == value).firstOrNull;
}

/// One of the user's activities.
///
/// Live activities occupy one of the eight grid [position]s (1–8). Deleted
/// activities keep their row (with [deletedAt] set and no position) so that
/// historical time entries stay readable. System activities ([role] set) are
/// never on the grid and cannot be renamed or deleted.
class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.isSystem,
    required this.createdAt,
    required this.deletedAt,
    this.role,
    this.icon,
    this.description,
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

  final SystemRole? role;

  /// Key into `activityIcons`, or null for no icon.
  final String? icon;

  /// What the activity is for, written by the user to help decide where a
  /// part of the day belongs. Null when not set (never empty).
  final String? description;

  bool get isDeleted => deletedAt != null;
  bool get isDefault => role == SystemRole.defaultActivity;

  /// Whether time may be assigned to it now: a grid activity or Default.
  bool get canTakeTime => !isDeleted && (position != null || isDefault);

  factory Activity.fromRow(Map<String, Object?> row) => Activity(
    id: row['id']! as int,
    name: row['name']! as String,
    color: row['color']! as int,
    position: row['position'] as int?,
    isSystem: row['is_system'] == 1,
    createdAt: fromStoredTimestamp(row['created_at']! as int),
    deletedAt: fromStoredTimestampOrNull(row['deleted_at']),
    role: SystemRole.parse(row['role']),
    icon: row['icon'] as String?,
    description: row['description'] as String?,
  );
}
