import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/schema.dart';

import '../support/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  Future<int> insertActivity({int? position, String name = 'A'}) => db.insert(
    'activities',
    {'name': name, 'color': 0, 'position': position, 'created_at': 0},
  );

  Future<int> insertEntry(int activityId, int start, int? end) => db.insert(
    'time_entries',
    {'activity_id': activityId, 'start_utc': start, 'end_utc': end},
  );

  test('creates the current schema version with foreign keys on', () async {
    expect(await db.getVersion(), schemaVersion);
    final fk = await db.rawQuery('PRAGMA foreign_keys');
    expect(fk.single.values.single, 1);
  });

  test('allows at most one open time entry', () async {
    final a = await insertActivity(position: 1);
    await insertEntry(a, 0, 10);
    await insertEntry(a, 10, 20);
    await insertEntry(a, 20, null);
    expect(() => insertEntry(a, 30, null), throwsA(isA<DatabaseException>()));
  });

  test('rejects negative durations', () async {
    final a = await insertActivity(position: 1);
    expect(() => insertEntry(a, 10, 5), throwsA(isA<DatabaseException>()));
  });

  test('rejects entries for unknown activities', () async {
    expect(() => insertEntry(999, 0, 1), throwsA(isA<DatabaseException>()));
  });

  test('never cascades activity deletion into time entries', () async {
    final a = await insertActivity(position: 1);
    await insertEntry(a, 0, 10);
    expect(
      () => db.delete('activities', where: 'id = ?', whereArgs: [a]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('time_entries'), hasLength(1));
  });

  test('live positions are unique and limited to 1-8', () async {
    await insertActivity(position: 1);
    expect(
      () => insertActivity(position: 1),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => insertActivity(position: 9),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a deleted activity frees its position', () async {
    final a = await insertActivity(position: 1);
    await db.update(
      'activities',
      {'deleted_at': 1},
      where: 'id = ?',
      whereArgs: [a],
    );
    await insertActivity(position: 1, name: 'B');
  });
}
