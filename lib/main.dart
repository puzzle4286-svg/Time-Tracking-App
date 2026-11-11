import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'app/app_shell.dart';
import 'app/settings_controller.dart';
import 'database/app_database.dart';
import 'database/seed.dart';
import 'repositories/settings_repository.dart';
import 'repositories/ui_state_store.dart';
import 'services/activities/activity_service.dart';
import 'services/history/history_service.dart';
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
  final activities = ActivityService(db, clock);
  await activities.load();

  runApp(
    TimeTrackerApp(
      settings: settings,
      home: AppShell(
        tracking: tracking,
        activities: activities,
        settings: settings,
        history: HistoryService(db),
        uiState: await UiStateStore.load(db),
        clock: clock,
      ),
    ),
  );
}
