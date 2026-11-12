import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/seed.dart';
import '../repositories/settings_repository.dart';
import '../repositories/ui_state_store.dart';
import '../services/activities/activity_service.dart';
import '../services/export/backup_files.dart';
import '../services/export/backup_service.dart';
import '../services/goals/goal_service.dart';
import '../services/history/entry_edit_service.dart';
import '../services/history/history_service.dart';
import '../services/tracking/tracking_service.dart';
import '../util/clock.dart';
import '../widgets/data/data_section.dart';
import 'app.dart';
import 'app_shell.dart';
import 'settings_controller.dart';

/// Every service, loaded from the database.
class AppServices {
  AppServices._({
    required this.settings,
    required this.tracking,
    required this.activities,
    required this.edits,
    required this.goals,
    required this.uiState,
  });

  final SettingsController settings;
  final TrackingService tracking;
  final ActivityService activities;
  final EntryEditService edits;
  final GoalService goals;
  final UiStateStore uiState;

  static Future<AppServices> load(Database db, Clock clock) async {
    await ensureSeeded(db, clock.now());
    final settingsRepository = SettingsRepository(db);
    final settings = SettingsController(
      settingsRepository,
      await settingsRepository.load(),
    );
    // Split at any midnights missed while the app was not running.
    final tracking = TrackingService(db, clock);
    await tracking.reconcile();
    final activities = ActivityService(db, clock, tracking);
    await activities.load();
    return AppServices._(
      settings: settings,
      tracking: tracking,
      activities: activities,
      edits: EntryEditService(db, clock, tracking),
      goals: GoalService(db, clock),
      uiState: await UiStateStore.load(db),
    );
  }
}

/// Owns the services. After a restore it loads them again and rebuilds the
/// whole widget tree, so no screen keeps state from the replaced data.
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.db,
    required this.clock,
    required this.services,
    this.files = const SystemBackupFiles(),
  });

  final Database db;
  final Clock clock;
  final AppServices services;
  final BackupFiles files;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late AppServices _services = widget.services;
  int _generation = 0;
  GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();
  late final _backup = BackupService(widget.db, widget.clock);

  Future<void> _reload() async {
    final next = await AppServices.load(widget.db, widget.clock);
    if (!mounted) return;
    // The old services are not disposed: screens being torn down may still
    // have pending callbacks into them. They are simply dropped.
    setState(() {
      _services = next;
      _generation++;
      _messenger = GlobalKey();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('Backup restored')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;
    return TimeTrackerApp(
      key: ValueKey(_generation),
      settings: s.settings,
      scaffoldMessengerKey: _messenger,
      home: AppShell(
        tracking: s.tracking,
        activities: s.activities,
        settings: s.settings,
        history: HistoryService(widget.db),
        edits: s.edits,
        goals: s.goals,
        uiState: s.uiState,
        db: widget.db,
        clock: widget.clock,
        data: DataActions(
          backup: _backup,
          files: widget.files,
          clock: widget.clock,
          onRestored: _reload,
        ),
      ),
    );
  }
}
