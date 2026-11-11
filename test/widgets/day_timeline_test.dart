import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/services/tracking/time_range.dart';
import 'package:time_tracker/widgets/timeline/day_timeline.dart';

void main() {
  final day = localDay(DateTime(2026, 11, 9));
  const ppm = DayTimeline.defaultPixelsPerMinute;

  DayEntry entry(int id, String name, DateTime start, DateTime? end) {
    final activity = Activity(
      id: id,
      name: name,
      color: 0xFF2196F3,
      position: id,
      isSystem: false,
      createdAt: start,
      deletedAt: null,
    );
    return DayEntry(
      entry: TimeEntry(id: id, activityId: id, start: start, end: end),
      activity: activity,
      start: start,
      end: end,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    List<DayEntry> entries,
    DateTime now,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DayTimeline(day: day, entries: entries, now: now),
        ),
      ),
    ),
  );

  testWidgets('block height is proportional to duration', (tester) async {
    await pump(tester, [
      entry(1, 'Sleep', DateTime(2026, 11, 9), DateTime(2026, 11, 9, 1)),
      entry(2, 'Work', DateTime(2026, 11, 9, 1), DateTime(2026, 11, 9, 3)),
    ], DateTime(2026, 11, 10, 12));

    final sleep = tester.getSize(
      find.byKey(const ValueKey('timeline-block-1')),
    );
    final work = tester.getSize(find.byKey(const ValueKey('timeline-block-2')));
    expect(sleep.height, 60 * ppm);
    expect(work.height, 120 * ppm);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('timeline-block-2'))).dy -
          tester.getTopLeft(find.byKey(const ValueKey('timeline-block-1'))).dy,
      60 * ppm,
    );
  });

  testWidgets('labels show name, times and duration beside long blocks', (
    tester,
  ) async {
    await pump(tester, [
      entry(1, 'Work', DateTime(2026, 11, 9, 9), DateTime(2026, 11, 9, 10, 30)),
    ], DateTime(2026, 11, 10, 12));
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('09:00 – 10:30 · 1h 30m'), findsOneWidget);
  });

  testWidgets('a running entry ends at now and today ends at now', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 9, 14);
    await pump(tester, [
      entry(1, 'Work', DateTime(2026, 11, 9, 13), null),
    ], now);
    expect(find.text('13:00 – now · 1h 0m'), findsOneWidget);
    expect(tester.getSize(find.byType(DayTimeline)).height, 14 * 60 * ppm);
  });

  testWidgets('an entry ending at midnight shows 24:00', (tester) async {
    await pump(tester, [
      entry(1, 'Gaming', DateTime(2026, 11, 9, 23), DateTime(2026, 11, 10)),
    ], DateTime(2026, 11, 11));
    expect(find.text('23:00 – 24:00 · 1h 0m'), findsOneWidget);
  });

  testWidgets('very short entries draw a block but no label', (tester) async {
    await pump(tester, [
      entry(1, 'Blip', DateTime(2026, 11, 9, 9), DateTime(2026, 11, 9, 9, 2)),
    ], DateTime(2026, 11, 10));
    expect(find.byKey(const ValueKey('timeline-block-1')), findsOneWidget);
    expect(find.text('Blip'), findsNothing);
  });

  test('day height uses the real day length', () {
    final full = DayTimeline.heightFor(day, DateTime(2026, 11, 12));
    expect(full, 24 * 60 * ppm);
    // On DST days localDay is 23 or 25 h; heightFor follows the range.
    final shortDay = TimeRange(
      DateTime.utc(2026, 3, 29),
      DateTime.utc(2026, 3, 29, 23),
    );
    expect(
      DayTimeline.heightFor(shortDay, DateTime.utc(2026, 4)),
      23 * 60 * ppm,
    );
  });
}
