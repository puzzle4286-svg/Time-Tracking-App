import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/app.dart';
import 'package:time_tracker/app/app_shell.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/history/history_service.dart';

import '../support/matchers.dart';
import '../support/tracking_fixture.dart';

void main() {
  final monday9 = DateTime(2026, 11, 9, 9);
  late TrackingFixture f;
  late ActivityService activities;
  late SettingsController settings;

  setUp(() async {
    f = await TrackingFixture.create(monday9);
    await f.service.reconcile();
    activities = ActivityService(f.db, f.clock);
    await activities.load();
    final repo = SettingsRepository(f.db);
    settings = SettingsController(repo, await repo.load());
  });
  tearDown(() => f.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      TimeTrackerApp(
        settings: settings,
        home: AppShell(
          tracking: f.service,
          activities: activities,
          settings: settings,
          history: HistoryService(f.db),
          clock: f.clock,
        ),
      ),
    );
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  /// Lets database futures and resulting rebuilds complete.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('shows the active activity and the 2x4 grid', (tester) async {
    await pumpApp(tester);
    expect(textOf(tester, 'current-activity-name'), 'Free Time');
    expect(textOf(tester, 'session-duration'), '0:00:00');
    for (var p = 1; p <= 8; p++) {
      expect(find.byKey(Key('activity-tile-$p')), findsOneWidget);
    }
    expect(find.text('Tap to set up'), findsNWidgets(5));
  });

  testWidgets('every grid tile fills an equal cell', (tester) async {
    await pumpApp(tester);
    final sizes = {
      for (var p = 1; p <= 8; p++)
        tester.getSize(find.byKey(Key('activity-tile-$p'))),
    };
    expect(sizes, hasLength(1));
  });

  testWidgets('display refreshes from timestamps', (tester) async {
    await pumpApp(tester);
    f.clock.advance(const Duration(hours: 1, minutes: 2, seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(textOf(tester, 'session-duration'), '1:02:03');
    expect(textOf(tester, 'today-total'), 'Today 1h 2m');
  });

  testWidgets('tapping an activity switches to it', (tester) async {
    await pumpApp(tester);
    f.clock.advance(const Duration(minutes: 30));
    await tester.tap(find.text('Gaming'));
    await settle(tester);

    expect(textOf(tester, 'current-activity-name'), 'Gaming');
    expect(textOf(tester, 'session-duration'), '0:00:00');
    final entries = await f.entries();
    expect(entries.where((e) => e.isOpen).single.activityId, f.gaming);
  });

  testWidgets('tapping the active activity creates no entry', (tester) async {
    await pumpApp(tester);
    f.clock.advance(const Duration(minutes: 30));
    await tester.tap(find.byKey(const Key('activity-tile-1')));
    await settle(tester);
    expect(await f.entries(), hasLength(1));
  });

  testWidgets('long press edits; rename shows in tile and header', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.longPress(find.byKey(const Key('activity-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit activity'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Leisure');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'current-activity-name'), 'Leisure');
    expect(find.text('Leisure'), findsNWidgets(2));
  });

  testWidgets('empty name is rejected in the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('activity-tile-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(activities.atPosition(4), isNull);
  });

  testWidgets('an empty slot can be set up', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('activity-tile-4')));
    await tester.pumpAndSettle();
    expect(find.text('Set up activity'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Reading');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(activities.atPosition(4)!.name, 'Reading');
    expect(find.text('Tap to set up'), findsNWidgets(4));
    // Setting up does not switch.
    expect(textOf(tester, 'current-activity-name'), 'Free Time');
  });

  testWidgets('midnight while visible starts a new daily entry', (
    tester,
  ) async {
    f.clock.set(DateTime(2026, 11, 9, 23, 59, 59));
    await f.service.reconcile();
    await pumpApp(tester);

    f.clock.set(DateTime(2026, 11, 10, 0, 0, 1));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    final entries = await f.entries();
    expect(entries, hasLength(2));
    expect(entries.first.end, isMoment(DateTime(2026, 11, 10)));
    expect(textOf(tester, 'session-duration'), '0:00:01');
  });

  testWidgets('resuming the app reconciles missed midnights', (tester) async {
    await pumpApp(tester);
    final binding = tester.binding;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    f.clock.set(DateTime(2026, 11, 12, 8)); // three midnights later
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await settle(tester);

    expect(await f.entries(), hasLength(4));
    expect(textOf(tester, 'session-duration'), '8:00:00');
  });

  testWidgets('settings change and persist appearance and accent', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Black'));
    await settle(tester);
    await tester.tap(find.text('Rose'));
    await settle(tester);
    await tester.pumpAndSettle(); // theme change animates

    final context = tester.element(find.text('Accent colour'));
    expect(Theme.of(context).scaffoldBackgroundColor, Colors.black);
    final stored = await SettingsRepository(f.db).load();
    expect(stored.appearance, AppearanceMode.black);
    expect(stored.accent, AccentPalette.rose);
  });

  testWidgets('grid is 2 rows x 4 columns, positions 1-4 on top', (
    tester,
  ) async {
    await pumpApp(tester);
    Offset at(int p) => tester.getTopLeft(find.byKey(Key('activity-tile-$p')));
    for (var p = 2; p <= 4; p++) {
      expect(at(p).dy, at(1).dy);
      expect(at(p).dx, greaterThan(at(p - 1).dx));
    }
    expect(at(5).dx, at(1).dx);
    expect(at(5).dy, greaterThan(at(1).dy));
  });

  testWidgets('history timeline shows today and scrolls back to past days', (
    tester,
  ) async {
    // Free Time since Monday 09:00; Gaming from Tuesday 10:00; now Wed 08:00.
    f.clock.set(DateTime(2026, 11, 10, 10));
    await f.service.switchTo(f.gaming);
    f.clock.set(DateTime(2026, 11, 11, 8));
    await f.service.reconcile();

    await pumpApp(tester);
    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('00:00 – now · 8h 0m'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('09:00 – 24:00 · 15h 0m'), // Monday's Free Time
      find.byKey(const Key('history-list')),
      const Offset(0, 400),
    );
    await settle(tester);
    expect(find.text('09:00 – 24:00 · 15h 0m'), findsOneWidget);
    // History ends at the first recorded day: nothing before Monday.
    expect(find.textContaining('Sun, 8 Nov'), findsNothing);
  });

  testWidgets('bottom navigation reaches every tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('History'));
    await settle(tester);
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Insights are coming soon.'), findsOneWidget);
    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('current-activity-name')), findsOneWidget);
  });
}
