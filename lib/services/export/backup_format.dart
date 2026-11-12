import 'dart:convert';
import 'dart:typed_data';

import '../../database/schema.dart';
import '../../util/timestamps.dart';

/// Identifies a backup file made by this app.
const backupFormatName = 'time-tracker-backup';

/// Version of the JSON envelope (not of the database schema).
const backupFormatVersion = 1;

enum ColumnType { integer, text }

class BackupColumn {
  const BackupColumn(this.name, this.type, {this.nullable = false});

  final String name;
  final ColumnType type;
  final bool nullable;
}

const _int = ColumnType.integer;
const _text = ColumnType.text;

/// Every table in a backup with its columns, in insert order (referenced
/// tables first). Must match the current schema; a test compares it with
/// `PRAGMA table_info`, so a new migration fails until this is updated.
const Map<String, List<BackupColumn>> backupTables = {
  'activities': [
    BackupColumn('id', _int),
    BackupColumn('name', _text),
    BackupColumn('color', _int),
    BackupColumn('position', _int, nullable: true),
    BackupColumn('is_system', _int),
    BackupColumn('created_at', _int),
    BackupColumn('deleted_at', _int, nullable: true),
    BackupColumn('role', _text, nullable: true),
    BackupColumn('icon', _text, nullable: true),
  ],
  'time_entries': [
    BackupColumn('id', _int),
    BackupColumn('activity_id', _int),
    BackupColumn('start_utc', _int),
    BackupColumn('end_utc', _int, nullable: true),
  ],
  'goals': [
    BackupColumn('id', _int),
    BackupColumn('activity_id', _int),
    BackupColumn('name', _text, nullable: true),
    BackupColumn('period_unit', _text),
    BackupColumn('period_length', _int),
    BackupColumn('anchor_year', _int),
    BackupColumn('anchor_month', _int),
    BackupColumn('anchor_day', _int),
    BackupColumn('anchor_minute', _int),
    BackupColumn('min_us', _int, nullable: true),
    BackupColumn('max_us', _int, nullable: true),
    BackupColumn('enabled', _int),
    BackupColumn('created_at', _int),
  ],
  'settings': [BackupColumn('key', _text), BackupColumn('value', _text)],
};

/// Oldest schema version a backup can have (backups exist since v4).
const minimumBackupSchemaVersion = 4;

/// Upgrades the raw tables of a backup made at schema version `n - 1` to
/// version `n`, mirroring `migrations[n]`. Needed for every migration that
/// changes a backed-up table.
final Map<int, void Function(Map<String, Object?> tables)> _rowUpgrades = {
  5: (tables) {
    for (final row in _rawRows(tables, 'activities')) {
      row.putIfAbsent('icon', () => null);
    }
  },
};

Iterable<Map<String, Object?>> _rawRows(
  Map<String, Object?> tables,
  String table,
) => (tables[table] is List ? tables[table]! as List : const <Object?>[])
    .whereType<Map<String, Object?>>();

/// The backup file could not be used. [message] is shown to the user.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

typedef Row = Map<String, Object?>;

/// A complete, validated backup: raw rows of every table.
class BackupData {
  BackupData._({
    required this.createdAt,
    required this.appVersion,
    required this.tables,
  });

  /// Wraps rows read from the database. Not validated: the database already
  /// enforces the same rules.
  BackupData.fromDatabase({
    required this.createdAt,
    required this.appVersion,
    required this.tables,
  });

  final DateTime createdAt;
  final String appVersion;
  final Map<String, List<Row>> tables;

  int get activityCount => tables['activities']!
      .where((r) => r['role'] == null && r['deleted_at'] == null)
      .length;
  int get entryCount => tables['time_entries']!.length;
  int get goalCount => tables['goals']!.length;

  /// Start of the earliest entry, or `null` if there are none.
  DateTime? get firstEntryStart {
    final starts = tables['time_entries']!.map((r) => r['start_utc']! as int);
    if (starts.isEmpty) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      starts.reduce((a, b) => a < b ? a : b),
      isUtc: true,
    );
  }

  Uint8List encode() {
    final json = {
      'format': backupFormatName,
      'formatVersion': backupFormatVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAtUtcUs': toStoredTimestamp(createdAt),
      'tables': tables,
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Parses and validates a backup file. Throws [BackupFormatException]
  /// with a user-facing reason if anything is wrong; nothing is changed by
  /// parsing.
  static BackupData parse(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException('The file is not a valid JSON file.');
    }
    if (json is! Map<String, Object?> || json['format'] != backupFormatName) {
      throw const BackupFormatException(
        'The file is not a Time Tracker backup.',
      );
    }
    final formatVersion = json['formatVersion'];
    final version = json['schemaVersion'];
    if (formatVersion is! int || version is! int) {
      throw const BackupFormatException('The backup has no version.');
    }
    if (formatVersion > backupFormatVersion || version > schemaVersion) {
      throw const BackupFormatException(
        'The backup was made by a newer version of the app. '
        'Update the app to restore it.',
      );
    }
    if (formatVersion < backupFormatVersion ||
        version < minimumBackupSchemaVersion) {
      throw const BackupFormatException(
        'The backup was made by an older version of the app that is not '
        'supported.',
      );
    }
    final createdAtUs = json['createdAtUtcUs'];
    if (createdAtUs is! int) {
      throw const BackupFormatException('The backup has no creation date.');
    }
    final rawTables = json['tables'];
    if (rawTables is! Map<String, Object?>) {
      throw const BackupFormatException('The backup contains no data.');
    }
    // Bring rows from an older app version up to the current schema.
    for (var v = version + 1; v <= schemaVersion; v++) {
      _rowUpgrades[v]?.call(rawTables);
    }
    final unknown = rawTables.keys.where((k) => !backupTables.containsKey(k));
    if (unknown.isNotEmpty) {
      throw BackupFormatException('Unknown table "${unknown.first}".');
    }
    final tables = {
      for (final MapEntry(key: table, value: columns) in backupTables.entries)
        table: _rows(table, columns, rawTables[table]),
    };
    _checkConsistency(tables);
    return BackupData._(
      createdAt: fromStoredTimestamp(createdAtUs),
      appVersion: '${json['appVersion'] ?? ''}',
      tables: tables,
    );
  }
}

List<Row> _rows(String table, List<BackupColumn> columns, Object? raw) {
  if (raw is! List<Object?>) {
    throw BackupFormatException('Table "$table" is missing.');
  }
  final names = {for (final c in columns) c.name};
  return [
    for (final (i, row) in raw.indexed)
      if (row is! Map<String, Object?>)
        throw BackupFormatException('Row ${i + 1} of "$table" is invalid.')
      else
        _row(table, i, columns, names, row),
  ];
}

Row _row(
  String table,
  int index,
  List<BackupColumn> columns,
  Set<String> names,
  Map<String, Object?> row,
) {
  String where(String column) => '"$column" in row ${index + 1} of "$table"';
  for (final key in row.keys) {
    if (!names.contains(key)) {
      throw BackupFormatException('Unknown column ${where(key)}.');
    }
  }
  for (final c in columns) {
    if (!row.containsKey(c.name)) {
      throw BackupFormatException('Missing ${where(c.name)}.');
    }
    final v = row[c.name];
    final ok = v == null
        ? c.nullable
        : switch (c.type) {
            ColumnType.integer => v is int,
            ColumnType.text => v is String,
          };
    if (!ok) throw BackupFormatException('Invalid value for ${where(c.name)}.');
  }
  return {for (final c in columns) c.name: row[c.name]};
}

/// Rules the database cannot express, or that give clearer messages here.
/// Column CHECKs and unique indexes are enforced again on insert.
void _checkConsistency(Map<String, List<Row>> tables) {
  Set<Object?> uniqueIds(String table, String column) {
    final seen = <Object?>{};
    for (final r in tables[table]!) {
      if (!seen.add(r[column])) {
        throw BackupFormatException('Duplicate $column in "$table".');
      }
    }
    return seen;
  }

  final activityIds = uniqueIds('activities', 'id');
  uniqueIds('time_entries', 'id');
  uniqueIds('goals', 'id');
  uniqueIds('settings', 'key');

  final roles = tables['activities']!.map((r) => r['role']).toList();
  for (final role in ['default', 'unavailable']) {
    if (roles.where((r) => r == role).length != 1) {
      throw BackupFormatException('The built-in "$role" activity is missing.');
    }
  }
  if (roles.any((r) => r != null && r != 'default' && r != 'unavailable')) {
    throw const BackupFormatException('Unknown activity role.');
  }

  for (final table in ['time_entries', 'goals']) {
    if (tables[table]!.any((r) => !activityIds.contains(r['activity_id']))) {
      throw BackupFormatException('"$table" refers to a missing activity.');
    }
  }

  // Entries must not overlap; only the latest may still be running.
  final entries = [
    ...tables['time_entries']!,
  ]..sort((a, b) => (a['start_utc']! as int).compareTo(b['start_utc']! as int));
  int? previousEnd;
  for (final (i, e) in entries.indexed) {
    final start = e['start_utc']! as int;
    final end = e['end_utc'] as int?;
    if (end != null && end < start) {
      throw const BackupFormatException('A time entry ends before it starts.');
    }
    if (previousEnd != null && start < previousEnd) {
      throw const BackupFormatException('Time entries overlap.');
    }
    if (end == null && i != entries.length - 1) {
      throw const BackupFormatException(
        'Only the latest time entry can be running.',
      );
    }
    previousEnd = end;
  }
}
