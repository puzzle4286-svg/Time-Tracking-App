import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/schema.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';

import '../support/test_database.dart';

void main() {
  test('v1 -> v2 converts millisecond timestamps to microseconds', () async {
    final dir = await Directory.systemTemp.createTemp('migration');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'app.db');

    // Build a v1 database exactly as the v1 app did.
    sqfliteFfiInit();
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final s in migrations[1]!) {
            await db.execute(s);
          }
        },
      ),
    );
    final startMs = DateTime.utc(2026, 11, 9, 8).millisecondsSinceEpoch;
    final endMs = DateTime.utc(2026, 11, 9, 9, 30).millisecondsSinceEpoch;
    final a = await v1.insert('activities', {
      'name': 'Free Time',
      'color': 0,
      'position': 1,
      'created_at': startMs,
      'deleted_at': null,
    });
    await v1.insert('activities', {
      'name': 'Old',
      'color': 0,
      'position': null,
      'created_at': startMs,
      'deleted_at': endMs,
    });
    await v1.insert('time_entries', {
      'activity_id': a,
      'start_utc': startMs,
      'end_utc': endMs,
    });
    await v1.insert('time_entries', {
      'activity_id': a,
      'start_utc': endMs,
      'end_utc': null,
    });
    await v1.close();

    final db = await openTestDatabase(path);
    addTearDown(db.close);
    expect(await db.getVersion(), schemaVersion);

    final entries = await db.query('time_entries', orderBy: 'id');
    expect(entries[0]['start_utc'], startMs * 1000);
    expect(entries[0]['end_utc'], endMs * 1000);
    expect(entries[1]['end_utc'], isNull);
    final activities = await db.query('activities', orderBy: 'id');
    expect(activities[0]['created_at'], startMs * 1000);
    expect(activities[0]['deleted_at'], isNull);
    expect(activities[1]['deleted_at'], endMs * 1000);

    // v3 adds the built-in Default activity to existing installs, without
    // touching their own activities.
    final defaults = await db.query('activities', where: "role = 'default'");
    expect(defaults.single['name'], 'Default');
    expect(defaults.single['position'], isNull);
    expect(
      (await db.query(
        'activities',
        where: 'id = ?',
        whereArgs: [a],
      )).single['position'],
      1,
    );

    final open = await TimeEntryRepository(db).openEntry();
    expect(open!.start, DateTime.utc(2026, 11, 9, 9, 30));
  });

  test('v4 -> v5 adds an empty icon to existing activities', () async {
    final dir = await Directory.systemTemp.createTemp('migration');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'app.db');
    sqfliteFfiInit();
    final v4 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          for (var v = 1; v <= 4; v++) {
            for (final s in migrations[v]!) {
              await db.execute(s);
            }
          }
        },
      ),
    );
    await v4.insert('activities', {
      'name': 'Reading',
      'color': 7,
      'position': 1,
      'created_at': 1,
    });
    await v4.close();

    final db = await openTestDatabase(path);
    addTearDown(db.close);
    final row = (await db.query('activities')).single;
    expect(row['name'], 'Reading');
    expect(row.containsKey('icon'), isTrue);
    expect(row['icon'], isNull);
  });
}
