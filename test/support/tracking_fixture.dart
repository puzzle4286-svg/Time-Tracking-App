import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/repositories/activity_repository.dart';
import 'package:time_tracker/services/tracking/tracking_service.dart';

import 'fake_clock.dart';
import 'test_database.dart';

/// Seeded database with Free Time (running), Gaming and Study, and a
/// [TrackingService] driven by a [FakeClock].
class TrackingFixture {
  TrackingFixture._(this.db, this.clock, this.freeTime, this.gaming, this.study)
    : service = TrackingService(db, clock);

  final Database db;
  final FakeClock clock;
  final TrackingService service;
  final int freeTime;
  final int gaming;
  final int study;

  static Future<TrackingFixture> create(
    DateTime installTime, {
    String path = inMemoryDatabasePath,
  }) async {
    final db = await openTestDatabase(path);
    await ensureSeeded(db, installTime);
    final activities = ActivityRepository(db);
    // Fresh installs start on Default with an empty grid; these tests use
    // a set-up user: Free Time at position 1, running since install.
    final freeTime = await activities.insert(
      name: 'Free Time',
      color: 0,
      position: 1,
      createdAt: installTime,
    );
    await db.update('time_entries', {
      'activity_id': freeTime,
    }, where: 'end_utc IS NULL');
    final gaming = await activities.insert(
      name: 'Gaming',
      color: 1,
      position: 2,
      createdAt: installTime,
    );
    final study = await activities.insert(
      name: 'Study',
      color: 2,
      position: 3,
      createdAt: installTime,
    );
    return TrackingFixture._(
      db,
      FakeClock(installTime),
      freeTime,
      gaming,
      study,
    );
  }

  /// Reopens an existing database file, as after an app restart.
  static Future<TrackingFixture> reopen(String path, DateTime now) async {
    final db = await openTestDatabase(path);
    await ensureSeeded(db, now);
    final ids = {
      for (final a in await ActivityRepository(db).liveActivities())
        a.name: a.id,
    };
    return TrackingFixture._(
      db,
      FakeClock(now),
      ids['Free Time']!,
      ids['Gaming']!,
      ids['Study']!,
    );
  }

  /// Every entry, oldest first.
  Future<List<TimeEntry>> entries() async {
    final rows = await db.query('time_entries', orderBy: 'start_utc, id');
    return rows.map(TimeEntry.fromRow).toList();
  }

  Future<void> close() => db.close();
}
