import '../util/timestamps.dart';

/// The unit of a goal's recurring period.
enum GoalUnit {
  hour,
  day,
  week,
  month;

  static GoalUnit parse(Object? value) =>
      values.firstWhere((u) => u.name == value);
}

/// A local wall-clock start, e.g. "2026-11-09 00:00". Stored as calendar
/// fields, not as an instant: it is a recurring calendar rule ("Monday 00:00
/// local"), so it keeps its meaning if the device timezone changes.
class GoalAnchor {
  const GoalAnchor({
    required this.year,
    required this.month,
    required this.day,
    required this.minuteOfDay,
  });

  factory GoalAnchor.fromLocal(DateTime t) {
    final l = t.toLocal();
    return GoalAnchor(
      year: l.year,
      month: l.month,
      day: l.day,
      minuteOfDay: l.hour * 60 + l.minute,
    );
  }

  final int year;
  final int month;
  final int day;

  /// 0–1439.
  final int minuteOfDay;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// The anchor as a local instant.
  DateTime toLocal() => DateTime(year, month, day, hour, minute);

  @override
  bool operator ==(Object other) =>
      other is GoalAnchor &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(year, month, day, minuteOfDay);
}

/// A time target for an activity within a recurring period, with an
/// optional minimum and/or maximum (at least one).
class Goal {
  const Goal({
    required this.id,
    required this.activityId,
    required this.name,
    required this.unit,
    required this.length,
    required this.anchor,
    required this.minimum,
    required this.maximum,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final int activityId;

  /// Optional description given by the user.
  final String? name;
  final GoalUnit unit;

  /// Number of units per period (>= 1).
  final int length;
  final GoalAnchor anchor;
  final Duration? minimum;
  final Duration? maximum;
  final bool enabled;
  final DateTime createdAt;

  factory Goal.fromRow(Map<String, Object?> row) => Goal(
    id: row['id']! as int,
    activityId: row['activity_id']! as int,
    name: row['name'] as String?,
    unit: GoalUnit.parse(row['period_unit']),
    length: row['period_length']! as int,
    anchor: GoalAnchor(
      year: row['anchor_year']! as int,
      month: row['anchor_month']! as int,
      day: row['anchor_day']! as int,
      minuteOfDay: row['anchor_minute']! as int,
    ),
    minimum: _duration(row['min_us']),
    maximum: _duration(row['max_us']),
    enabled: row['enabled'] == 1,
    createdAt: fromStoredTimestamp(row['created_at']! as int),
  );
}

Duration? _duration(Object? micros) =>
    micros == null ? null : Duration(microseconds: micros as int);
