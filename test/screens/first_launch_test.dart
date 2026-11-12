import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/app/app.dart';
import 'package:time_tracker/app/app_shell.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/repositories/ui_state_store.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/services/tracking/tracking_service.dart';

import '../support/fake_clock.dart';
import '../support/test_database.dart';

void main() {
  late Database db;
  late FakeClock clock;
  late TrackingService tracking;
  late ActivityService activities;
  late SettingsController settings;
  late UiStateStore uiState;

  setUp(() async {
    clock = FakeClock(DateTime(2026, 11, 12, 9));
    db = await openTestDatabase();
    await ensureSeeded(db, clock.now());
    tracking = TrackingService(db, clock);
    await tracking.reconcile();
    activities = ActivityService(db, clock, tracking);
    await activities.load();
    final repo = SettingsRepository(db);
    settings = SettingsController(repo, await repo.load());
    uiState = await UiStateStore.load(db);
  });
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    TimeTrackerApp(
      settings: settings,
      home: AppShell(
        tracking: tracking,
        activities: activities,
        settings: settings,
        history: HistoryService(db),
        edits: EntryEditService(db, clock, tracking),
        uiState: uiState,
        clock: clock,
      ),
    ),
  );

  testWidgets('starts on Default with all eight slots empty', (tester) async {
    await pumpApp(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('current-activity-name'))).data,
      'Default',
    );
    expect(find.byIcon(Icons.add), findsNWidgets(8));
    expect(find.byIcon(Icons.pause_rounded), findsNothing); // not on grid
  });

  testWidgets('the only grid activity can be deleted while running; '
      'Default takes over', (tester) async {
    final reading = await activities.create(
      position: 1,
      name: 'Reading',
      color: 0xFF4CAF50,
    );
    clock.advance(const Duration(minutes: 10));
    await tracking.switchTo(reading.id);
    clock.advance(const Duration(minutes: 10));
    await pumpApp(tester);

    await tester.longPress(find.byKey(const Key('activity-tile-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete activity'));
    await tester.pumpAndSettle();
    expect(find.text('It is running now. Continue with:'), findsOneWidget);
    expect(find.text('Default'), findsWidgets); // successor preselected
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('current-activity-name'))).data,
      'Default',
    );
    expect(find.byIcon(Icons.add), findsNWidgets(8));
  });
}
