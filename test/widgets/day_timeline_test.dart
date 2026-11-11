import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/services/tracking/time_range.dart';
import 'package:time_tracker/widgets/timeline/day_timeline.dart';

import '../support/day_entries.dart';

void main() {
  final day = localDay(DateTime(2026, 11, 9));
  const ppm = DayTimeline.pixelsPerMinute;

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

  Size blockSize(WidgetTester tester, int id) =>
      tester.getSize(find.byKey(ValueKey('timeline-block-$id')));

  testWidgets('long blocks are proportional to duration', (tester) async {
    await pump(tester, [
      dayEntry(1, 'Sleep', DateTime(2026, 11, 9), DateTime(2026, 11, 9, 1)),
      dayEntry(2, 'Work', DateTime(2026, 11, 9, 1), DateTime(2026, 11, 9, 3)),
    ], DateTime(2026, 11, 10, 12));
    expect(blockSize(tester, 1).height, 60 * ppm);
    expect(blockSize(tester, 2).height, 120 * ppm);
  });

  testWidgets('every entry is shown and labelled, even seconds long', (
    tester,
  ) async {
    await pump(tester, [
      dayEntry(1, 'Work', DateTime(2026, 11, 9, 9), DateTime(2026, 11, 9, 10)),
      dayEntry(
        2,
        'Coffee',
        DateTime(2026, 11, 9, 10),
        DateTime(2026, 11, 9, 10, 0, 40),
      ),
      dayEntry(
        3,
        'Call',
        DateTime(2026, 11, 9, 10, 0, 40),
        DateTime(2026, 11, 9, 10, 3),
      ),
    ], DateTime(2026, 11, 10));

    for (final name in ['Work', 'Coffee', 'Call']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('10:00 – 10:00 · 40s'), findsOneWidget);
    expect(find.text('10:00 – 10:03 · 2m'), findsOneWidget);
    expect(
      blockSize(tester, 2).height,
      greaterThanOrEqualTo(DayTimeline.minBlockHeight),
    );
  });

  testWidgets('a running entry ends at now; today ends at now', (tester) async {
    final now = DateTime(2026, 11, 9, 14);
    await pump(tester, [
      dayEntry(1, 'Work', DateTime(2026, 11, 9, 13), null),
    ], now);
    expect(find.text('13:00 – now · 1h 0m'), findsOneWidget);
    expect(tester.getSize(find.byType(DayTimeline)).height, 14 * 60 * ppm);
  });

  testWidgets('an entry ending at midnight shows 24:00', (tester) async {
    await pump(tester, [
      dayEntry(1, 'Gaming', DateTime(2026, 11, 9, 23), DateTime(2026, 11, 10)),
    ], DateTime(2026, 11, 11));
    expect(find.text('23:00 – 24:00 · 1h 0m'), findsOneWidget);
  });

  test('a full day is 24 h tall; DST days follow their real length', () {
    expect(
      DayTimeline.layoutFor(day, const [], DateTime(2026, 11, 12)).height,
      24 * 60 * ppm,
    );
    final shortDay = TimeRange(
      DateTime.utc(2026, 3, 29),
      DateTime.utc(2026, 3, 29, 23),
    );
    expect(
      DayTimeline.layoutFor(shortDay, const [], DateTime.utc(2026, 4)).height,
      23 * 60 * ppm,
    );
  });
}
