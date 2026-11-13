import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/app.dart';
import 'package:time_tracker/app/app_shell.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/repositories/ui_state_store.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/goals/goal_service.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';
import 'package:time_tracker/services/history/history_service.dart';

import '../support/tracking_fixture.dart';

/// Every screen and sheet laid out on a phone held sideways (a Pixel-sized
/// 900 × 408 dp screen with status bar, navigation bar and camera cutout),
/// with no layout overflow anywhere.
void main() {
  late TrackingFixture f;
  late ActivityService activities;
  late GoalService goals;
  late SettingsController settings;
  late UiStateStore uiState;

  setUp(() async {
    f = await TrackingFixture.create(DateTime(2026, 11, 9, 9));
    await f.service.reconcile();
    activities = ActivityService(f.db, f.clock, f.service);
    await activities.load();
    goals = GoalService(f.db, f.clock);
    final repo = SettingsRepository(f.db);
    settings = SettingsController(repo, await repo.load());
    uiState = await UiStateStore.load(f.db);
  });
  tearDown(() => f.close());

  void landscape(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(2700, 1224)
      ..padding = const FakeViewPadding(left: 120, top: 72, bottom: 48)
      ..viewPadding = const FakeViewPadding(left: 120, top: 72, bottom: 48);
    addTearDown(tester.view.reset);
  }

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
          goals: goals,
          uiState: uiState,
          db: f.db,
          clock: f.clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fails with every overflow reported while [body] runs, by screen.
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Map<String, Future<void> Function()> screens,
  ) async {
    final problems = <String>[];
    final previous = FlutterError.onError;
    var current = '';
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        problems.add('$current: ${text.split('\n').first}');
      } else {
        previous?.call(details);
      }
    };
    try {
      for (final MapEntry(:key, :value) in screens.entries) {
        current = key;
        await value();
        await tester.pumpAndSettle();
      }
    } finally {
      FlutterError.onError = previous;
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }

  testWidgets('no screen overflows in landscape', (tester) async {
    landscape(tester);
    // A goal on the running activity, so the main screen shows its bar.
    await goals.create(
      f.freeTime,
      GoalDraft(
        name: 'Rest',
        unit: GoalUnit.day,
        length: 1,
        anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
        minimum: const Duration(hours: 1),
      ),
    );
    // Free Time 09-10, Gaming 10-11, Free Time 11-now (12:00).
    f.clock.set(DateTime(2026, 11, 9, 10));
    await f.service.switchTo(f.gaming);
    f.clock.set(DateTime(2026, 11, 9, 11));
    await f.service.switchTo(f.freeTime);
    f.clock.set(DateTime(2026, 11, 9, 12));
    await activities.update(
      f.study,
      name: 'Study',
      color: activities.byId(f.study)!.color,
      description:
          'Lectures, homework, exam prep and everything else that '
          'belongs to university courses',
    );

    Future<void> tab(String label) async {
      await tester.tap(find.text(label).last);
    }

    Future<void> closeSheet() async {
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    }

    await expectNoOverflow(tester, {
      'Track': () => pumpApp(tester),
      'Activity editor': () async {
        await tester.longPress(find.byKey(const Key('activity-tile-1')));
      },
      'Activity editor (closed)': closeSheet,
      'Set up activity': () async {
        await tester.tap(find.byKey(const Key('activity-tile-5')));
      },
      'Set up activity (closed)': closeSheet,
      'Which activity?': () async {
        await tester.fling(
          find.byKey(const Key('activity-grid')),
          const Offset(0, -120),
          800,
        );
      },
      'Which activity? (closed)': closeSheet,
      'Goals page': () async {
        await tester.longPress(find.byKey(const Key('activity-tile-1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Goals'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Goals'));
      },
      'Goal editor': () async {
        await tester.tap(find.text('Add goal'));
      },
      'Goal editor (back)': () async {
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
      },
      'Rearrange grid': () async {
        await tester.longPress(find.byKey(const Key('activity-tile-1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Rearrange grid'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rearrange grid'));
      },
      'Rearrange grid (back)': () => tester.pageBack(),
      'History': () => tab('History'),
      'Entry actions': () async {
        final gaming = (await f.entries())[1];
        final block = find.byKey(ValueKey('timeline-block-${gaming.id}'));
        await tester.ensureVisible(block);
        await tester.pumpAndSettle();
        await tester.tap(block);
      },
      'Entry editor': () async {
        await tester.tap(find.text('Change start / end'));
      },
      'Entry editor (closed)': () async {
        Navigator.of(tester.element(find.byKey(const Key('pick-end')))).pop();
      },
      'Insights': () => tab('Insights'),
      'Settings': () => tab('Settings'),
    });
  });
}
