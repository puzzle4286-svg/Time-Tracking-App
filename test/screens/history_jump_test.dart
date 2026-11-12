import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/repositories/ui_state_store.dart';
import 'package:time_tracker/screens/history/history_screen.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/util/timestamps.dart';

import '../support/tracking_fixture.dart';

/// Counts how History loads its days.
class CountingHistory extends HistoryService {
  CountingHistory(super.db);

  int dayQueries = 0;
  int rangeQueries = 0;

  @override
  Future<List<DayEntry>> entriesForDay(DateTime day) {
    dayQueries++;
    return super.entriesForDay(day);
  }

  @override
  Future<Map<DateTime, List<DayEntry>>> entriesForDays(
    DateTime first,
    DateTime last,
  ) {
    // entriesForDay delegates here with a single day; count real ranges.
    if (first != last) rangeQueries++;
    return super.entriesForDays(first, last);
  }
}

void main() {
  testWidgets('a position a year back loads with one range query', (
    tester,
  ) async {
    // A year of history: running since a year ago, split at every midnight.
    final f = await TrackingFixture.create(DateTime(2025, 11, 12, 9));
    addTearDown(f.close);
    f.clock.set(DateTime(2026, 11, 12, 8));
    await f.service.reconcile();
    expect(await f.entries(), hasLength(366));

    final uiState = await UiStateStore.load(f.db);
    await uiState.set(
      HistoryScreen.anchorKey,
      '${toStoredTimestamp(DateTime(2026, 1, 17, 0, 30))}',
    );
    final activities = ActivityService(f.db, f.clock, f.service);
    await activities.load();
    final history = CountingHistory(f.db);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(
            history: history,
            tracking: f.service,
            edits: EntryEditService(f.db, f.clock, f.service),
            activities: activities,
            uiState: uiState,
            onOpenDay: (_) {},
            clock: f.clock,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The restored day is on screen, loaded together with the 300 days
    // after it; only the few days the list builds on its own load singly.
    expect(find.textContaining('17 Jan 2026'), findsOneWidget);
    expect(history.rangeQueries, 1);
    expect(history.dayQueries, lessThan(10));
  });
}
