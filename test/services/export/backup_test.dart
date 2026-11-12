import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/schema.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/services/export/backup_format.dart';
import 'package:time_tracker/services/export/backup_service.dart';
import 'package:time_tracker/util/timestamps.dart';

import '../../support/fake_clock.dart';
import '../../support/test_database.dart';
import '../../support/tracking_fixture.dart';

void main() {
  final monday9 = DateTime(2026, 11, 9, 9);
  late TrackingFixture f;
  late BackupService backup;

  /// Every table's rows, for comparing whole databases.
  Future<Map<String, List<Map<String, Object?>>>> dump(Database db) async => {
    for (final t in backupTables.keys)
      t: await db.query(t, orderBy: t == 'settings' ? 'key' : 'id'),
  };

  setUp(() async {
    f = await TrackingFixture.create(monday9);
    f.clock.set(monday9.add(const Duration(hours: 1)));
    await f.service.switchTo(f.gaming);
    f.clock.set(monday9.add(const Duration(hours: 2, microseconds: 7)));
    await f.service.switchTo(f.study);
    await f.db.insert('goals', {
      'activity_id': f.study,
      'name': 'Study daily',
      'period_unit': 'day',
      'period_length': 1,
      'anchor_year': 2026,
      'anchor_month': 11,
      'anchor_day': 9,
      'anchor_minute': 0,
      'min_us': 3600000000,
      'max_us': null,
      'enabled': 1,
      'created_at': toStoredTimestamp(monday9),
    });
    await f.db.insert('settings', {'key': 'appearance', 'value': 'light'});
    backup = BackupService(f.db, f.clock);
  });
  tearDown(() => f.close());

  test('column list matches the current schema', () async {
    final tables = await f.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    expect(tables.map((r) => r['name']).toSet(), backupTables.keys.toSet());
    for (final MapEntry(key: table, value: columns) in backupTables.entries) {
      final info = await f.db.rawQuery('PRAGMA table_info($table)');
      expect(
        [for (final c in info) c['name']],
        [for (final c in columns) c.name],
        reason: table,
      );
      for (final (i, c) in columns.indexed) {
        // NOT NULL in the schema ⇔ not nullable in the backup. Primary keys
        // are never null in practice even where SQLite would allow it.
        if (info[i]['pk'] != 0) continue;
        expect(info[i]['notnull'] == 0, c.nullable, reason: '$table.${c.name}');
      }
    }
  });

  test('backup → file → restore reproduces every table exactly', () async {
    final before = await dump(f.db);
    final bytes = (await backup.createBackup()).encode();

    final other = await openTestDatabase();
    await ensureSeeded(other, DateTime(2025));
    await other.insert('activities', {
      'name': 'Old',
      'color': 5,
      'position': 4,
      'created_at': 1,
    });
    await BackupService(
      other,
      FakeClock(monday9),
    ).restore(BackupData.parse(bytes));
    expect(await dump(other), before);
    await other.close();
  });

  test('file contains versions and metadata', () async {
    final json =
        jsonDecode(utf8.decode((await backup.createBackup()).encode()))
            as Map<String, Object?>;
    expect(json['format'], backupFormatName);
    expect(json['formatVersion'], backupFormatVersion);
    expect(json['schemaVersion'], schemaVersion);
    expect(json['createdAtUtcUs'], f.clock.now().microsecondsSinceEpoch);
  });

  test('summary counts', () async {
    final data = BackupData.parse((await backup.createBackup()).encode());
    expect(data.activityCount, 3); // Free Time, Gaming, Study
    expect(data.entryCount, 3);
    expect(data.goalCount, 1);
    expect(data.firstEntryStart, monday9.toUtc());
  });

  group('CSV export', () {
    test('every entry, oldest first, running entry last', () async {
      f.clock.set(monday9.add(const Duration(hours: 3, microseconds: 7)));
      final lines = utf8.decode(await backup.exportCsv()).split('\r\n');
      expect(lines, hasLength(5));
      expect(lines[1], startsWith('Free Time,'));
      expect(lines[1], endsWith(',3600000000'));
      expect(lines[2], startsWith('Gaming,'));
      expect(lines[3], startsWith('Study,'));
      expect(lines[3].split(',')[2], isEmpty);
      expect(lines[3].split(',')[4], isEmpty);
      expect(lines[3], endsWith(',3600000000'));
    });
  });

  group('validation', () {
    late Map<String, Object?> good;
    setUp(() async {
      good =
          jsonDecode(utf8.decode((await backup.createBackup()).encode()))
              as Map<String, Object?>;
    });

    List<Map<String, Object?>> rows(Map<String, Object?> json, String t) =>
        ((json['tables']! as Map)[t]! as List).cast<Map<String, Object?>>();

    void expectRejected(
      void Function(Map<String, Object?> json) mutate,
      String message,
    ) {
      final json = jsonDecode(jsonEncode(good)) as Map<String, Object?>;
      mutate(json);
      expect(
        () => BackupData.parse(utf8.encode(jsonEncode(json))),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    }

    test('accepts the unmodified file', () {
      expect(BackupData.parse(utf8.encode(jsonEncode(good))), isNotNull);
    });

    test('not JSON / not a backup', () {
      expect(
        () => BackupData.parse(utf8.encode('{nope')),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupData.parse(utf8.encode('[1, 2]')),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupData.parse([0xff, 0xfe, 0x00]),
        throwsA(isA<BackupFormatException>()),
      );
      expectRejected((j) => j['format'] = 'other', 'not a Lifestring');
    });

    test('versions', () {
      expectRejected((j) => j['schemaVersion'] = schemaVersion + 1, 'newer');
      expectRejected(
        (j) => j['formatVersion'] = backupFormatVersion + 1,
        'newer',
      );
      expectRejected(
        (j) => j['schemaVersion'] = minimumBackupSchemaVersion - 1,
        'older',
      );
      expectRejected((j) => j.remove('schemaVersion'), 'no version');
    });

    test('structure', () {
      expectRejected((j) => (j['tables']! as Map).remove('goals'), 'missing');
      expectRejected(
        (j) => (j['tables']! as Map)['x'] = <Object?>[],
        'Unknown table',
      );
      expectRejected(
        (j) => rows(j, 'activities').first['extra'] = 1,
        'Unknown column',
      );
      expectRejected(
        (j) => rows(j, 'activities').first.remove('color'),
        'Missing',
      );
      expectRejected(
        (j) => rows(j, 'activities').first['name'] = 5,
        'Invalid value',
      );
      expectRejected(
        (j) => rows(j, 'time_entries').first['start_utc'] = null,
        'Invalid value',
      );
      expectRejected(
        (j) => rows(j, 'time_entries').first['start_utc'] = 1.5,
        'Invalid value',
      );
      expectRejected((j) => j.remove('createdAtUtcUs'), 'creation date');
    });

    test('consistency', () {
      expectRejected(
        (j) => rows(j, 'time_entries').last['activity_id'] = 999,
        'missing activity',
      );
      expectRejected(
        (j) => rows(j, 'goals').first['activity_id'] = 999,
        'missing activity',
      );
      expectRejected(
        (j) => rows(j, 'activities').removeWhere((r) => r['role'] == 'default'),
        '"default" activity is missing',
      );
      expectRejected(
        (j) => rows(j, 'activities').last['id'] = 1,
        'Duplicate id',
      );
      expectRejected(
        (j) => rows(j, 'time_entries').first['end_utc'] = null,
        'Only the latest',
      );
      expectRejected((j) {
        final e = rows(j, 'time_entries').first;
        e['end_utc'] = (e['end_utc']! as int) + 1;
      }, 'overlap');
      expectRejected((j) {
        final e = rows(j, 'time_entries').first;
        e['end_utc'] = (e['start_utc']! as int) - 1;
      }, 'ends before');
    });
  });

  test(
    'a backup from schema v4 (before icons) is upgraded and restores',
    () async {
      await f.db.update('activities', {
        'icon': 'reading',
      }, where: 'id = ${f.study}');
      final json =
          jsonDecode(utf8.decode((await backup.createBackup()).encode()))
              as Map<String, Object?>;
      json['schemaVersion'] = 4;
      for (final row in (json['tables']! as Map)['activities']! as List) {
        (row as Map).remove('icon');
      }
      final data = BackupData.parse(utf8.encode(jsonEncode(json)));
      await backup.restore(data);
      final icons = (await f.db.query('activities')).map((r) => r['icon']);
      expect(icons, everyElement(isNull));
      expect(await f.db.query('activities'), hasLength(5));
    },
  );

  test('a backup the database rejects changes nothing', () async {
    final before = await dump(f.db);
    final json =
        jsonDecode(utf8.decode((await backup.createBackup()).encode()))
            as Map<String, Object?>;
    // Passes the file checks, fails the CHECK constraint on insert.
    (((json['tables']! as Map)['activities']! as List).last
            as Map)['position'] =
        9;
    final data = BackupData.parse(utf8.encode(jsonEncode(json)));
    await expectLater(
      backup.restore(data),
      throwsA(isA<BackupFormatException>()),
    );
    expect(await dump(f.db), before);
  });

  test(
    'after restore, tracking continues the restored running entry',
    () async {
      final data = BackupData.parse((await backup.createBackup()).encode());
      f.clock.set(monday9.add(const Duration(hours: 5)));
      await f.service.switchTo(f.gaming);
      await backup.restore(data);

      f.clock.set(monday9.add(const Duration(days: 1, hours: 1)));
      await f.service.reconcile();
      expect(f.service.current.activity.id, f.study);
      final entries = await f.entries();
      // Study 11:00 → midnight, then a new Study entry from midnight.
      expect(entries, hasLength(4));
      expect(entries[2].end, DateTime(2026, 11, 10).toUtc());
      expect(entries[3].isOpen, isTrue);
    },
  );

  test('file names use the local date and time', () {
    final t = DateTime(2026, 3, 4, 5, 6);
    expect(backupFileName(t), 'lifestring-backup-2026-03-04-0506.json');
    expect(csvFileName(t), 'lifestring-entries-2026-03-04-0506.csv');
  });
}
