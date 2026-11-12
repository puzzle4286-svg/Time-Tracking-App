import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';
import 'package:time_tracker/services/history/history_service.dart';
import 'package:time_tracker/services/tracking/time_range.dart';

import '../../support/matchers.dart';
import '../../support/tracking_fixture.dart';

void main() {
  late TrackingFixture f;
  late HistoryService history;

  setUp(() async {
    f = await TrackingFixture.create(DateTime(2026, 11, 9, 22));
    await f.service.reconcile();
    history = HistoryService(f.db);
    f.clock.set(DateTime(2026, 11, 9, 23));
    await f.service.switchTo(f.gaming);
    f.clock.set(DateTime(2026, 11, 10, 1, 30));
    await f.service.switchTo(f.study);
    f.clock.set(DateTime(2026, 11, 10, 3));
  });
  tearDown(() => f.close());

  test('returns the day\'s entries in order with activities', () async {
    final monday = await history.entriesForDay(DateTime(2026, 11, 9, 12));
    expect(monday.map((e) => e.activity.name), ['Free Time', 'Gaming']);
    expect(monday.last.end, isMoment(DateTime(2026, 11, 10)));

    final tuesday = await history.entriesForDay(DateTime(2026, 11, 10));
    expect(tuesday.map((e) => e.activity.name), ['Gaming', 'Study']);
    expect(tuesday.last.end, isNull);
    expect(tuesday.last.durationAt(f.clock.now()), const Duration(minutes: 90));
  });

  test('clips entries that extend beyond the day', () async {
    // An edited entry spanning two days (possible after history edits).
    await f.db.insert('time_entries', {
      'activity_id': f.gaming,
      'start_utc': DateTime(2026, 11, 7, 20).toUtc().microsecondsSinceEpoch,
      'end_utc': DateTime(2026, 11, 8, 4).toUtc().microsecondsSinceEpoch,
    });
    final saturday = await history.entriesForDay(DateTime(2026, 11, 8));
    expect(saturday.single.start, isMoment(DateTime(2026, 11, 8)));
    expect(saturday.single.durationAt(f.clock.now()), const Duration(hours: 4));
  });

  test('deleted activities still resolve with their name', () async {
    await f.db.update(
      'activities',
      {'deleted_at': 1, 'position': null},
      where: 'id = ?',
      whereArgs: [f.gaming],
    );
    final monday = await history.entriesForDay(DateTime(2026, 11, 9));
    expect(monday.last.activity.name, 'Gaming');
    expect(monday.last.activity.isDeleted, isTrue);
  });

  test('firstDay is the local day of the oldest entry', () async {
    expect(await history.firstDay(), DateTime(2026, 11, 9));
  });

  test('entriesForDays matches entriesForDay for every day', () async {
    int us(DateTime t) => t.toUtc().microsecondsSinceEpoch;
    // A range across the October / November DST changes of most zones in
    // tool/test_timezones.sh, with an entry spanning four days and a
    // zero-length entry exactly at midnight.
    await f.db.insert('time_entries', {
      'activity_id': f.gaming,
      'start_utc': us(DateTime(2026, 10, 24, 20)),
      'end_utc': us(DateTime(2026, 10, 27, 4)),
    });
    await f.db.insert('time_entries', {
      'activity_id': f.study,
      'start_utc': us(DateTime(2026, 11, 1)),
      'end_utc': us(DateTime(2026, 11, 1)),
    });
    final byDay = await history.entriesForDays(
      DateTime(2026, 11, 10, 15),
      DateTime(2026, 10, 20), // either order
    );
    expect(byDay.keys.first, DateTime(2026, 10, 20));
    expect(byDay.keys.last, DateTime(2026, 11, 10));
    expect(byDay, hasLength(22));
    String describe(List<DayEntry> l) =>
        l.map((e) => '${e.entry.id} ${e.start} ${e.end}').join('; ');
    // Independent reference: the repository's SQL overlap query per day,
    // clipped by hand.
    Future<String> reference(DateTime day) async {
      final r = localDay(day);
      final rows = await TimeEntryRepository(f.db).overlapping(r.start, r.end);
      return rows
          .map((e) {
            final start = e.start.isBefore(r.start) ? r.start : e.start;
            final end = e.end != null && e.end!.isAfter(r.end) ? r.end : e.end;
            return '${e.id} $start $end';
          })
          .join('; ');
    }

    for (final MapEntry(key: day, value: entries) in byDay.entries) {
      expect(describe(entries), await reference(day), reason: '$day');
      expect(
        describe(await history.entriesForDay(day)),
        describe(entries),
        reason: '$day',
      );
    }
    expect(
      byDay[DateTime(2026, 10, 25)]!.single.durationAt(f.clock.now()),
      localDayLength(DateTime(2026, 10, 25)),
    );
  });
}

Duration localDayLength(DateTime day) => DateTime(
  day.year,
  day.month,
  day.day + 1,
).difference(DateTime(day.year, day.month, day.day));
