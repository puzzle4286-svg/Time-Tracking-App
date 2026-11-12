import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/repositories/activity_repository.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';

import '../support/matchers.dart';
import '../support/test_database.dart';

void main() {
  final installTime = DateTime(2026, 11, 11, 9, 30);

  group('first launch', () {
    late Database db;

    setUp(() async {
      db = await openTestDatabase();
      await ensureSeeded(db, installTime);
    });
    tearDown(() => db.close());

    test('all eight grid positions are empty', () async {
      expect(await ActivityRepository(db).liveActivities(), isEmpty);
    });

    test('creates the built-in Default and Unavailable activities', () async {
      final repo = ActivityRepository(db);
      final def = await repo.withRole(SystemRole.defaultActivity);
      final unavailable = await repo.withRole(SystemRole.unavailable);
      expect(def!.name, defaultActivityName);
      expect(def.position, isNull);
      expect(def.canTakeTime, isTrue);
      expect(unavailable!.name, unavailableActivityName);
      expect(unavailable.canTakeTime, isFalse);
    });

    test('Default is active from the install time', () async {
      final def = await ActivityRepository(
        db,
      ).withRole(SystemRole.defaultActivity);
      final open = await TimeEntryRepository(db).openEntry();
      expect(open!.activityId, def!.id);
      expect(open.start, isMoment(installTime));
      expect(await db.query('time_entries'), hasLength(1));
    });

    test('built-in activities cannot be renamed or deleted', () async {
      final repo = ActivityRepository(db);
      final def = (await repo.withRole(SystemRole.defaultActivity))!;
      expect(() => repo.update(def.id, name: 'X', color: 0), throwsStateError);
      expect(() => repo.softDelete(def.id, installTime), throwsStateError);
    });

    test('seeding again does nothing', () async {
      await ensureSeeded(db, installTime.add(const Duration(hours: 5)));
      expect(await ActivityRepository(db).count(), 2);
      expect(await db.query('time_entries'), hasLength(1));
    });
  });

  test('active state survives closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('time_tracker_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'app.db');

    final first = await openTestDatabase(path);
    await ensureSeeded(first, installTime);
    await first.close();

    final reopened = await openTestDatabase(path);
    addTearDown(reopened.close);
    await ensureSeeded(reopened, installTime.add(const Duration(days: 1)));

    final open = await TimeEntryRepository(reopened).openEntry();
    expect(open!.start, isMoment(installTime));
    expect(await ActivityRepository(reopened).count(), 2);
  });
}
