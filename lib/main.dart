import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'app/settings_controller.dart';
import 'database/app_database.dart';
import 'database/seed.dart';
import 'repositories/settings_repository.dart';
import 'services/tracking/tracking_service.dart';
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

  // Split at any midnights missed while the app was not running.
  final tracking = TrackingService(db, clock);
  await tracking.reconcile();

  runApp(
    TimeTrackerApp(
      settings: settings,
      // Temporary home until Phase 3.
      home: Scaffold(
        body: Center(child: Text('Active: ${tracking.current.activity.name}')),
      ),
    ),
  );
}
