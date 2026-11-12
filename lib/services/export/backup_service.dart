import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../app/app_info.dart';
import '../../util/clock.dart';
import '../../util/timestamps.dart';
import 'backup_format.dart';
import 'csv_export.dart';

/// Reads the database for exports and replaces it on restore.
class BackupService {
  BackupService(this._db, this._clock);

  final Database _db;
  final Clock _clock;

  /// All time entries, oldest first, as CSV (see [buildEntriesCsv]).
  Future<Uint8List> exportCsv() async {
    final rows = await _db.rawQuery('''
      SELECT a.name, e.start_utc, e.end_utc
      FROM time_entries e JOIN activities a ON a.id = e.activity_id
      ORDER BY e.start_utc, e.id
    ''');
    final entries = [
      for (final r in rows)
        CsvEntry(
          activity: r['name']! as String,
          start: fromStoredTimestamp(r['start_utc']! as int),
          end: fromStoredTimestampOrNull(r['end_utc']),
        ),
    ];
    return utf8.encode(buildEntriesCsv(entries, _clock.now()));
  }

  /// Every row of every table, read in one transaction so it is consistent.
  Future<BackupData> createBackup() async {
    final tables = await _db.transaction(
      (txn) async => {
        for (final table in backupTables.keys)
          table: await txn.query(table, orderBy: _orderBy(table)),
      },
    );
    return BackupData.fromDatabase(
      createdAt: _clock.now(),
      appVersion: appVersion,
      tables: tables,
    );
  }

  /// Replaces all data with [backup] in one transaction. On any error
  /// nothing is changed. Afterwards every service must be reloaded.
  Future<void> restore(BackupData backup) async {
    try {
      await _db.transaction((txn) async {
        for (final table in backupTables.keys.toList().reversed) {
          await txn.delete(table);
        }
        final batch = txn.batch();
        for (final table in backupTables.keys) {
          for (final row in backup.tables[table]!) {
            batch.insert(table, row);
          }
        }
        await batch.commit(noResult: true);
      });
    } on DatabaseException catch (e) {
      // A CHECK, foreign key or unique index rejected the data.
      throw BackupFormatException('The backup is inconsistent ($e).');
    }
  }

  static String _orderBy(String table) => table == 'settings' ? 'key' : 'id';
}

/// Suggested file names, e.g. `time-tracker-backup-2026-11-12-1330.json`.
String backupFileName(DateTime now) =>
    'time-tracker-backup-${_stamp(now)}.json';

String csvFileName(DateTime now) => 'time-tracker-entries-${_stamp(now)}.csv';

String _stamp(DateTime now) {
  final t = now.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}';
}
