import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/app.dart';
import 'package:time_tracker/app/app_shell.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/models/activity_icons.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/repositories/ui_state_store.dart';
import 'package:time_tracker/screens/home/home_goals.dart';
import 'package:time_tracker/screens/home/home_screen.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/goals/goal_service.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/widgets/activities/activity_tile.dart';
import 'package:time_tracker/widgets/goals/goal_bars.dart';

import '../support/matchers.dart';
import '../support/test_database.dart';
import '../support/tracking_fixture.dart';

void main() {
  final monday9 = DateTime(2026, 11, 9, 9);
  late TrackingFixture f;
  late ActivityService activities;
  late SettingsController settings;
  late UiStateStore uiState;

  setUp(() async {
    f = await TrackingFixture.create(monday9);
    await f.service.reconcile();
    activities = ActivityService(f.db, f.clock, f.service);
    await activities.load();
    final repo = SettingsRepository(f.db);
    settings = SettingsController(repo, await repo.load());
    uiState = await UiStateStore.load(f.db);
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
          edits: EntryEditService(f.db, f.clock, f.service),
          goals: GoalService(f.db, f.clock),
          uiState: uiState,
          db: f.db,
          clock: f.clock,
        ),
      ),
    );
  }

  /// Grid positions whose tile is shown as active.
  List<int> activeTiles(WidgetTester tester) => [
    for (var p = 1; p <= 8; p++)
      if (tester
          .widget<ActivityTile>(find.byKey(Key('activity-tile-$p')))
          .isActive)
        p,
  ];

  Color tileFill(WidgetTester tester, int position) => tester
      .widget<Material>(
        find.descendant(
          of: find.byKey(Key('activity-tile-$position')),
          matching: find.byType(Material),
        ),
      )
      .color!;

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
    expect(find.byIcon(Icons.add), findsNWidgets(5));
    // No icons set: tiles show the first letter; Free Time is active.
    for (final letter in ['F', 'G', 'S']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(activeTiles(tester), [1]);
  });

  testWidgets('every grid tile fills an equal cell', (tester) async {
    await pumpApp(tester);
    final sizes = {
      for (var p = 1; p <= 8; p++)
        tester.getSize(find.byKey(Key('activity-tile-$p'))),
    };
    expect(sizes, hasLength(1));
  });

  testWidgets('grid is compact and the highlight follows the active one', (
    tester,
  ) async {
    await pumpApp(tester);
    final tile = tester.getSize(find.byKey(const Key('activity-tile-1')));
    expect(tile.height, HomeScreen.tileHeight);

    await tester.tap(find.byKey(const Key('activity-tile-2')));
    await settle(tester);
    expect(activeTiles(tester), [2]);
    // Active: full colour; others: muted tint.
    final context = tester.element(find.byKey(const Key('activity-tile-2')));
    final scheme = Theme.of(context).colorScheme;
    expect(tileFill(tester, 2), Color(activities.byId(f.gaming)!.color));
    expect(
      tileFill(tester, 1),
      ActivityTile.fillFor(scheme, activities.byId(f.freeTime), false),
    );
    expect(
      tileFill(tester, 1),
      isNot(Color(activities.byId(f.freeTime)!.color)),
    );
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
    await tester.tap(find.byKey(const Key('activity-tile-2')));
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
    expect(activities.byId(f.freeTime)!.name, 'Leisure');
  });

  testWidgets(
    'an icon chosen in the editor shows on the tile; None clears it',
    (tester) async {
      await pumpApp(tester);
      final tile = find.byKey(const Key('activity-tile-2'));
      expect(
        find.descendant(of: tile, matching: find.text('G')),
        findsOneWidget,
      );

      Future<void> pickIcon(String key) async {
        await tester.longPress(tile);
        await tester.pumpAndSettle();
        final option = find.byKey(Key('icon-option-$key'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await pickIcon('gaming');
      expect(activities.byId(f.gaming)!.icon, 'gaming');
      expect(
        find.descendant(
          of: tile,
          matching: find.byIcon(activityIcons['gaming']!),
        ),
        findsOneWidget,
      );

      await pickIcon('none');
      expect(activities.byId(f.gaming)!.icon, isNull);
      expect(
        find.descendant(of: tile, matching: find.text('G')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the running activity\'s goals show under the header', (
    tester,
  ) async {
    final goalService = GoalService(f.db, f.clock);
    GoalDraft daily({String? name, Duration? min, Duration? max}) => GoalDraft(
      name: name,
      unit: GoalUnit.day,
      length: 1,
      anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
      minimum: min,
      maximum: max,
    );
    final limit = await goalService.create(
      f.gaming,
      daily(
        name: 'Limit',
        min: const Duration(minutes: 30),
        max: const Duration(hours: 2),
      ),
    );
    final unnamed = await goalService.create(
      f.gaming,
      daily(max: const Duration(hours: 3)),
    );
    final study = await goalService.create(
      f.study,
      daily(min: const Duration(hours: 1)),
    );
    await pumpApp(tester);
    await settle(tester);
    // Free Time runs and has no goals.
    expect(find.byType(GoalBar), findsNothing);

    await tester.tap(find.byKey(const Key('activity-tile-2'))); // Gaming
    await settle(tester);
    f.clock.advance(const Duration(minutes: 45));
    await tester.pump(HomeGoals.refresh);
    await settle(tester);
    expect(find.byKey(ValueKey('home-goal-${limit.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('home-goal-${unnamed.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('home-goal-${study.id}')), findsNothing);
    expect(find.byType(GoalBar), findsNWidgets(2));
    // Goal name only; the activity name is not repeated next to the dot.
    expect(find.text('Limit'), findsOneWidget);
    expect(find.text('Gaming · Limit'), findsNothing);
    expect(textOf(tester, 'home-goal-tracked-${limit.id}'), '45m');
    expect(find.textContaining('min 30m · max 2h 0m · until'), findsOneWidget);
    // Right under the header, well above the grid.
    expect(
      tester.getTopLeft(find.byKey(ValueKey('home-goal-${limit.id}'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('activity-tile-1'))).dy / 2,
      ),
    );

    await tester.tap(find.byKey(const Key('activity-tile-3'))); // Study
    await settle(tester);
    expect(find.byKey(ValueKey('home-goal-${study.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('home-goal-${limit.id}')), findsNothing);
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
    expect(find.byIcon(Icons.add), findsNWidgets(4));
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

  testWidgets('accent row scrolls horizontally and remembers its position', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('accent-list'));
    expect(find.text('Slate'), findsNothing); // off-screen at first
    await tester.drag(list, const Offset(-300, 0));
    await tester.pumpAndSettle();
    final offset = tester.widget<ListView>(list).controller!.offset;
    expect(offset, greaterThan(0));
    await settle(tester);
    expect(
      double.parse(uiState.get('settings.accentScroll')!),
      closeTo(offset, 0.1),
    );

    // Leave the tab and come back: same position.
    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListView>(list).controller!.offset,
      closeTo(offset, 0.1),
    );

    // A fresh store (as after an app restart) sees the saved value.
    final reloaded = await UiStateStore.load(f.db);
    expect(reloaded.getDouble('settings.accentScroll'), closeTo(offset, 0.1));
  });

  group('history live updates', () {
    // Free Time since Monday 09:00; Gaming since Tuesday 10:00; now Wed 08:00.
    Future<void> openHistory(WidgetTester tester) async {
      f.clock.set(DateTime(2026, 11, 10, 10));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 11, 8));
      await f.service.reconcile();
      await pumpApp(tester);
      await tester.tap(find.text('History'));
      await settle(tester);
    }

    ScrollController controller(WidgetTester tester) => tester
        .widget<ListView>(find.byKey(const Key('history-list')))
        .controller!;

    testWidgets('running duration updates every second', (tester) async {
      await openHistory(tester);
      expect(find.text('00:00 – now · 8h 0m'), findsOneWidget);
      f.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00 – now · 8h 5m'), findsOneWidget);
    });

    testWidgets('at the bottom the view follows now', (tester) async {
      await openHistory(tester);
      final label = find.text('00:00 – now · 8h 0m');
      final before = tester.getTopLeft(label).dy;

      f.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(controller(tester).offset, 0);
      // The running block grew by 5 min, so its top moved up by 20 px.
      final after = tester.getTopLeft(find.text('00:00 – now · 8h 5m')).dy;
      expect(before - after, closeTo(5 * 4.0, 0.5));
    });

    testWidgets('scrolled into the past, the visible moment stays put', (
      tester,
    ) async {
      await openHistory(tester);
      await tester.dragUntilVisible(
        find.text('10:00 – 24:00 · 14h 0m'), // Tuesday's Gaming
        find.byKey(const Key('history-list')),
        const Offset(0, 300),
      );
      await settle(tester);
      final label = find.text('10:00 – 24:00 · 14h 0m');
      final before = tester.getTopLeft(label).dy;

      f.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(tester.getTopLeft(label).dy, closeTo(before, 0.5));
    });

    testWidgets('scrolled up within today, the visible moment stays put', (
      tester,
    ) async {
      await openHistory(tester);
      // Scroll up a little: today is still on screen but no longer at now.
      await tester.drag(
        find.byKey(const Key('history-list')),
        const Offset(0, 300),
      );
      await settle(tester);
      expect(controller(tester).offset, greaterThan(100));
      final sevenAm = find.descendant(
        of: find.byKey(ValueKey(DateTime(2026, 11, 11))),
        matching: find.text('07:00'),
      );
      final before = tester.getTopLeft(sevenAm).dy;

      f.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(tester.getTopLeft(sevenAm).dy, closeTo(before, 0.5));
    });

    testWidgets('position is saved as an instant and restored', (tester) async {
      await openHistory(tester);
      expect(uiState.get('history.anchor'), anyOf(isNull, 'now'));

      await tester.dragUntilVisible(
        find.text('10:00 – 24:00 · 14h 0m'),
        find.byKey(const Key('history-list')),
        const Offset(0, 300),
      );
      await settle(tester);
      final saved = uiState.get('history.anchor')!;
      expect(int.tryParse(saved), isNotNull);
      final label = find.text('10:00 – 24:00 · 14h 0m');
      final before = tester.getTopLeft(label).dy;

      // Leave and return after 10 minutes: same moment at the same place.
      await tester.tap(find.text('Track'));
      await settle(tester);
      f.clock.advance(const Duration(minutes: 10));
      await tester.tap(find.text('History'));
      await settle(tester);
      await tester.pump();

      expect(tester.getTopLeft(label).dy, closeTo(before, 1));

      // Scrolling back to the bottom saves "now".
      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      expect(uiState.get('history.anchor'), 'now');
    });
  });

  group('delete activity', () {
    Future<void> openDelete(WidgetTester tester, int position) async {
      await tester.longPress(find.byKey(Key('activity-tile-$position')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete activity'));
      await tester.pumpAndSettle();
    }

    testWidgets('an activity without history is simply deleted', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDelete(tester, 2); // Gaming, never tracked
      expect(find.text('It has no recorded time.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(activities.atPosition(2), isNull);
      expect(find.byIcon(Icons.add), findsNWidgets(6));
    });

    testWidgets('history is kept under a new name by default', (tester) async {
      f.clock.advance(const Duration(hours: 1));
      await f.service.switchTo(f.gaming);
      f.clock.advance(const Duration(hours: 1));
      await f.service.switchTo(f.freeTime);
      await pumpApp(tester);

      await openDelete(tester, 2);
      expect(find.textContaining('1 past entry'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final day = await HistoryService(f.db).entriesForDay(f.clock.now());
      expect(day.map((e) => e.activity.name), contains('Gaming (deleted)'));
      expect(activities.atPosition(2), isNull);
    });

    testWidgets('deleting the running activity hands over to another', (
      tester,
    ) async {
      f.clock.advance(const Duration(hours: 1));
      await pumpApp(tester);
      await openDelete(tester, 1); // Free Time, running
      expect(find.text('It is running now. Continue with:'), findsOneWidget);
      await tester.tap(find.text('Mark them as "Unavailable"'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'current-activity-name'), 'Gaming');
      expect(activities.atPosition(1), isNull);
      final day = await HistoryService(f.db).entriesForDay(f.clock.now());
      expect(day.first.activity.name, 'Unavailable');
    });
  });

  group('edit entries from History', () {
    Future<void> openHistoryWithEntries(WidgetTester tester) async {
      // Free Time 09-10, Gaming 10-11, Free Time 11-now (12:00).
      f.clock.set(DateTime(2026, 11, 9, 10));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 9, 11));
      await f.service.switchTo(f.freeTime);
      f.clock.set(DateTime(2026, 11, 9, 12));
      await pumpApp(tester);
      await tester.tap(find.text('History'));
      await settle(tester);
    }

    Future<void> tapGamingBlock(WidgetTester tester) async {
      final gaming = (await f.entries())[1];
      await tester.tap(find.byKey(ValueKey('timeline-block-${gaming.id}')));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping an entry offers the edit actions', (tester) async {
      await openHistoryWithEntries(tester);
      await tapGamingBlock(tester);
      for (final label in ['Change activity', 'Change start / end', 'Delete']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Split'), findsNothing);
    });

    testWidgets('change activity', (tester) async {
      await openHistoryWithEntries(tester);
      await tapGamingBlock(tester);
      await tester.tap(find.text('Change activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Study'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect((await f.entries())[1].activityId, f.study);
      expect(find.text('Study'), findsWidgets); // timeline refreshed
    });

    testWidgets('changing an end lists affected entries grouped by effect', (
      tester,
    ) async {
      await openHistoryWithEntries(tester);
      await tapGamingBlock(tester);
      await tester.tap(find.text('Change start / end'));
      await tester.pumpAndSettle();

      // End 11:00 -> 11:30 via the real pickers.
      await tester.tap(find.byKey(const Key('pick-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // keep the date
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '11');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('This changes other entries'), findsOneWidget);
      expect(find.text('This entry will be shortened:'), findsOneWidget);
      expect(find.text('1h 0m → 30m 0s'), findsOneWidget); // running Free Time
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(RegExp(r'\d:\d')),
        ),
        findsNothing,
        reason: 'the dialog shows durations, not clock times',
      );

      await tester.tap(find.text('Apply'));
      await settle(tester);
      await tester.pumpAndSettle();
      final entries = await f.entries();
      expect(entries[1].end, isMoment(DateTime(2026, 11, 9, 11, 30)));
      expect(entries[2].start, isMoment(DateTime(2026, 11, 9, 11, 30)));
    });

    testWidgets('freed time lists activities directly, Default last', (
      tester,
    ) async {
      await openHistoryWithEntries(tester);
      await tapGamingBlock(tester);
      await tester.tap(find.text('Change start / end'));
      await tester.pumpAndSettle();

      // End 11:00 -> 10:30 frees 30 min before the following Free Time.
      await tester.tap(find.byKey(const Key('pick-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '10');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('Fill the freed time'), findsOneWidget);
      expect(find.text('Leave empty'), findsNothing);
      expect(find.text('Another activity'), findsNothing);
      final labels = tester
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .map((t) => ((t.title! as Row).children[2] as Expanded).child)
          .map((w) => (w as Text).data)
          .toList();
      // Grid activities except Gaming itself, the neighbour marked, Default last.
      expect(labels, ['Free Time (following)', 'Study', 'Default']);

      await tester.tap(find.text('Next')); // neighbour preselected
      await settle(tester);
      await tester.pumpAndSettle();
      final entries = await f.entries();
      expect(entries.last.start, isMoment(DateTime(2026, 11, 9, 10, 30)));
    });

    testWidgets('delete between the same activity merges into one entry', (
      tester,
    ) async {
      await openHistoryWithEntries(tester);
      await tapGamingBlock(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // Free Time on both sides: one option, not three identical ones.
      expect(find.text('Fill with Free Time'), findsOneWidget);
      expect(find.textContaining('Split evenly'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await tester.pumpAndSettle();

      final entries = await f.entries();
      expect(entries, hasLength(1));
      expect(entries.single.start, isMoment(DateTime(2026, 11, 9, 9)));
      expect(find.text('09:00 – now · 3h 0m'), findsOneWidget);
    });

    testWidgets('day header shows the Info placeholder', (tester) async {
      await openHistoryWithEntries(tester);
      expect(find.text('Info'), findsWidgets);
      expect(find.textContaining('tracked'), findsNothing);
    });
  });

  group('goals', () {
    Future<void> openGoals(WidgetTester tester) async {
      await tester.longPress(
        find.byKey(const Key('activity-tile-2')),
      ); // Gaming
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goals'));
      await settle(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('add a daily minimum goal and see its progress', (
      tester,
    ) async {
      // Gaming ran 10:00–11:30 today (install Monday 09:00).
      f.clock.set(DateTime(2026, 11, 9, 10));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 9, 11, 30));
      await f.service.switchTo(f.freeTime);
      await pumpApp(tester);
      await openGoals(tester);
      expect(find.text('Goals · Gaming'), findsOneWidget);
      expect(find.text('No goals yet.'), findsOneWidget);

      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      expect(find.text('New goal'), findsOneWidget);
      // Defaults: every 1 day from 00:00, minimum 1 h.
      await tester.enterText(find.byKey(const Key('Minimum-h')), '2');
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('Every day from 00:00'), findsOneWidget);
      expect(find.text('Minimum'), findsOneWidget);
      expect(find.text('1h 30m of 2h 0m · 75% · 30m to go'), findsOneWidget);
    });

    testWidgets('maximum progress and exceeding it', (tester) async {
      f.clock.set(DateTime(2026, 11, 9, 10));
      await f.service.switchTo(f.gaming); // running
      f.clock.set(DateTime(2026, 11, 9, 11));
      await GoalService(f.db, f.clock).create(
        f.gaming,
        GoalDraft(
          unit: GoalUnit.day,
          length: 1,
          anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
          maximum: const Duration(hours: 2),
        ),
      );
      await pumpApp(tester);
      await openGoals(tester);
      expect(find.text('1h 0m of 2h 0m used · 1h 0m left'), findsOneWidget);

      // Two more hours pass while Gaming runs; the page refreshes itself.
      f.clock.set(DateTime(2026, 11, 9, 13));
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('Maximum exceeded'), findsOneWidget);
      expect(find.text('3h 0m of 2h 0m · over by 1h 0m'), findsOneWidget);
    });

    testWidgets('a goal needs a minimum or a maximum', (tester) async {
      await pumpApp(tester);
      await openGoals(tester);
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('Minimum-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Set a minimum, a maximum, or both'), findsOneWidget);
      expect(find.text('New goal'), findsOneWidget); // still open
    });

    testWidgets('edit and delete a goal', (tester) async {
      await GoalService(f.db, f.clock).create(
        f.gaming,
        GoalDraft(
          name: 'Limit games',
          unit: GoalUnit.week,
          length: 1,
          anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
          maximum: const Duration(hours: 10),
        ),
      );
      await pumpApp(tester);
      await openGoals(tester);
      expect(find.text('Limit games'), findsOneWidget);
      expect(find.text('Every week from Monday 00:00'), findsOneWidget);

      await tester.tap(find.text('Limit games'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('No goals yet.'), findsOneWidget);
    });
  });

  group('insights', () {
    // Monday 9 Nov: Free Time 09–10, Gaming 10–12, Free Time 12–now(14).
    // Sunday 8 Nov is before install, so last week is empty.
    Future<void> openInsights(WidgetTester tester) async {
      f.clock.set(DateTime(2026, 11, 9, 10));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 9, 12));
      await f.service.switchTo(f.freeTime);
      f.clock.set(DateTime(2026, 11, 9, 14));
      await pumpApp(tester);
      await tester.tap(find.text('Insights'));
      await settle(tester);
      await tester.pumpAndSettle();
    }

    String periodLabel(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('insights-period'))).data!;

    testWidgets('distribution uses the full day; the rest counts as Default', (
      tester,
    ) async {
      await openInsights(tester);
      expect(periodLabel(tester), 'Today');
      expect(find.byKey(const Key('distribution-total')), findsNothing);
      String share(int id) =>
          tester.widget<Text>(find.byKey(ValueKey('share-$id'))).data!;
      // 00:00–09:00 before install is not counted; 09–14 tracked, 14–24
      // Default: Free Time 3 h / 15 h, Gaming 2 h, Default 10 h, Study 0.
      expect(share(f.freeTime), '20%');
      expect(share(f.gaming), '13%');
      expect(share(f.study), '0%');
      final defaultId = await roleId(f.db, 'default');
      expect(share(defaultId), '67%');
      expect(find.textContaining('counts as Default'), findsNothing);

      // Default is listed last.
      final dy = {
        for (final id in [f.freeTime, f.gaming, f.study, defaultId])
          id: tester.getTopLeft(find.byKey(ValueKey('share-$id'))).dy,
      };
      expect(
        dy[defaultId],
        greaterThan(
          dy.values
              .where((v) => v != dy[defaultId])
              .reduce((a, b) => a > b ? a : b),
        ),
      );
    });

    testWidgets('comparison lists every activity; empty previous is zero', (
      tester,
    ) async {
      await openInsights(tester);
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('bar-previous-${f.study}')),
        200,
      );
      expect(find.text('Today vs Yesterday'), findsOneWidget);
      expect(find.text('+3h 0m'), findsOneWidget); // Free Time vs nothing
      expect(find.textContaining('still in progress'), findsNothing);
    });

    testWidgets('the period selector drives both charts', (tester) async {
      await openInsights(tester);
      // Next is disabled for the current period.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Week'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(periodLabel(tester), '9 – 15 Nov 2026');
      // The selector stays pinned at the top while the results scroll.
      Offset selectorAt() => tester.getTopLeft(find.byTooltip('Previous'));
      final pinned = selectorAt();
      await tester.scrollUntilVisible(find.text('This week vs Last week'), 200);
      expect(find.text('This week vs Last week'), findsOneWidget);
      expect(selectorAt(), pinned);
      expect(find.byTooltip('Previous').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Previous'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(periodLabel(tester), '2 – 8 Nov 2026');
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('share-${f.freeTime}')),
        -200,
      );
      expect(
        tester.widget<Text>(find.byKey(ValueKey('share-${f.freeTime}'))).data,
        '0%',
      );
      await tester.scrollUntilVisible(
        find.text('Last week vs 26 Oct – 1 Nov 2026'),
        200,
      );
      expect(find.text('Last week vs 26 Oct – 1 Nov 2026'), findsOneWidget);
      expect(selectorAt(), pinned);

      // Tapping the label returns to the current period.
      await tester.tap(find.byKey(const Key('insights-period')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(periodLabel(tester), '9 – 15 Nov 2026');

      await tester.tap(find.text('All'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(periodLabel(tester), 'All time');
      expect(find.textContaining(' vs '), findsNothing); // no comparison
    });

    testWidgets('Info in History opens that day in Insights', (tester) async {
      f.clock.set(DateTime(2026, 11, 10, 9)); // Tuesday
      await f.service.reconcile();
      await pumpApp(tester);
      await tester.tap(find.text('History'));
      await settle(tester);
      await tester.dragUntilVisible(
        find.byKey(ValueKey('day-info-${DateTime(2026, 11, 9)}')),
        find.byKey(const Key('history-list')),
        const Offset(0, 300),
      );
      final info = find.byKey(ValueKey('day-info-${DateTime(2026, 11, 9)}'));
      await tester.ensureVisible(info);
      await tester.pumpAndSettle();
      await tester.tap(info);
      await settle(tester);
      await tester.pumpAndSettle();
      expect(periodLabel(tester), 'Yesterday');
      // Monday 09:00–24:00 was Free Time only.
      expect(
        tester.widget<Text>(find.byKey(ValueKey('share-${f.freeTime}'))).data,
        '100%',
      );
    });
  });

  testWidgets('bottom navigation reaches every tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('History'));
    await settle(tester);
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    await tester.tap(find.text('Insights'));
    await settle(tester);
    expect(find.byKey(const Key('insights-period')), findsOneWidget);
    await tester.tap(find.text('Track'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('current-activity-name')), findsOneWidget);
  });
}
