import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'app/settings_controller.dart';
import 'database/app_database.dart';
import 'database/seed.dart';
import 'repositories/activity_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/time_entry_repository.dart';
import 'util/clock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const clock = SystemClock();

  final db = await openAppDatabase(
    databaseFactory,
    p.join(await getDatabasesPath(), databaseFileName),
  );
  await ensureSeeded(db, clock.now());

  final settingsRepository = SettingsRepository(db);
  final settings = SettingsController(
    settingsRepository,
    await settingsRepository.load(),
  );

  // Temporary Phase 1 home: proves storage and seeding are wired up.
  final open = await TimeEntryRepository(db).openEntry();
  final activities = await ActivityRepository(db).liveActivities();
  final activeName = activities
      .where((a) => a.id == open?.activityId)
      .firstOrNull
      ?.name;

  runApp(
    TimeTrackerApp(
      settings: settings,
      home: Scaffold(body: Center(child: Text('Active: ${activeName ?? '-'}'))),
    ),
  );
}
