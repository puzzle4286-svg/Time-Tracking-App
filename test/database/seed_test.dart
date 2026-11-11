import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/repositories/activity_repository.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';

import '../support/test_database.dart';

void main() {
  // Models always return local DateTimes (same instant as stored UTC).
  final installTime = DateTime(2026, 11, 11, 9, 30);

  group('first launch', () {
    late Database db;

    setUp(() async {
      db = await openTestDatabase();
      await ensureSeeded(db, installTime);
    });
    tearDown(() => db.close());

    test(
      'creates Free Time as the only grid activity, at position 1',
      () async {
        final live = await ActivityRepository(db).liveActivities();
        expect(live, hasLength(1));
        expect(live.single.name, initialActivityName);
        expect(live.single.position, 1);
        expect(live.single.createdAt, installTime);
      },
    );

    test('creates a hidden system Unavailable activity', () async {
      final system = await ActivityRepository(db).systemActivity();
      expect(system, isNotNull);
      expect(system!.name, unavailableActivityName);
      expect(system.position, isNull);
    });

    test('Free Time is active from the install time', () async {
      final live = await ActivityRepository(db).liveActivities();
      final open = await TimeEntryRepository(db).openEntry();
      expect(open, isNotNull);
      expect(open!.activityId, live.single.id);
      expect(open.start, installTime);
      expect(await db.query('time_entries'), hasLength(1));
    });

    test('seeding again does nothing', () async {
      await ensureSeeded(db, installTime.add(const Duration(hours: 5)));
      expect(await ActivityRepository(db).count(), 2);
      expect(await db.query('time_entries'), hasLength(1));
      final open = await TimeEntryRepository(db).openEntry();
      expect(open!.start, installTime);
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
    expect(open!.start, installTime);
    expect(await ActivityRepository(reopened).count(), 2);
  });
}
