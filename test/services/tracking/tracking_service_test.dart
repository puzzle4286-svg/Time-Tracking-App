import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';
import 'package:time_tracker/services/tracking/time_range.dart';
import 'package:time_tracker/services/tracking/tracking_service.dart';

import '../../support/matchers.dart';
import '../../support/test_database.dart';
import '../../support/tracking_fixture.dart';

void main() {
  // Monday 2026-11-09, 09:00 local.
  final monday9 = DateTime(2026, 11, 9, 9);
  late TrackingFixture f;

  setUp(() async {
    f = await TrackingFixture.create(monday9);
    await f.service.reconcile();
  });
  tearDown(() => f.close());

  /// Exactly one open entry, and the entries never overlap or leave gaps.
  Future<List<TimeEntry>> expectConsistent() async {
    final entries = await f.entries();
    expect(entries.where((e) => e.isOpen), hasLength(1));
    expect(entries.last.isOpen, isTrue);
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].start, entries[i - 1].end, reason: 'contiguous at $i');
    }
    return entries;
  }

  group('initial state', () {
    test('Free Time is active from install', () {
      expect(f.service.current.activity.id, f.freeTime);
      expect(f.service.current.entry.start, isMoment(monday9));
    });

    test('current is unavailable before the first reconcile', () {
      final fresh = TrackingService(f.db, f.clock);
      expect(() => fresh.current, throwsStateError);
    });
  });

  group('switching', () {
    test('ends the previous entry and starts the new one at now', () async {
      f.clock.advance(const Duration(minutes: 30));
      await f.service.switchTo(f.gaming);

      final entries = await expectConsistent();
      expect(entries, hasLength(2));
      expect(entries[0].activityId, f.freeTime);
      expect(
        entries[0].end,
        isMoment(monday9.add(const Duration(minutes: 30))),
      );
      expect(entries[1].activityId, f.gaming);
      expect(entries[1].start, entries[0].end);
      expect(f.service.current.activity.id, f.gaming);
    });

    test('selecting the active activity creates nothing', () async {
      f.clock.advance(const Duration(minutes: 10));
      await f.service.switchTo(f.freeTime);
      f.clock.advance(const Duration(minutes: 10));
      await f.service.switchTo(f.freeTime);

      final entries = await expectConsistent();
      expect(entries, hasLength(1));
      expect(entries.single.start, isMoment(monday9));
    });

    test('a zero-length session leaves no empty entry', () async {
      f.clock.advance(const Duration(minutes: 5));
      await f.service.switchTo(f.gaming);
      await f.service.switchTo(f.study); // same instant

      final entries = await expectConsistent();
      expect(entries.map((e) => e.activityId), [f.freeTime, f.study]);
    });

    test('many switches keep exactly one open entry', () async {
      final order = [f.gaming, f.study, f.freeTime, f.gaming, f.study];
      for (final id in order) {
        f.clock.advance(const Duration(minutes: 7));
        await f.service.switchTo(id);
      }
      final entries = await expectConsistent();
      expect(entries, hasLength(order.length + 1));
    });

    test('refuses unknown, deleted and system activities unchanged', () async {
      final system = await roleId(f.db, 'unavailable');
      await f.db.update(
        'activities',
        {'deleted_at': 1, 'position': null},
        where: 'id = ?',
        whereArgs: [f.study],
      );
      f.clock.advance(const Duration(minutes: 5));

      for (final id in [999, system, f.study]) {
        await expectLater(f.service.switchTo(id), throwsArgumentError);
      }
      final entries = await expectConsistent();
      expect(entries, hasLength(1));
      expect(f.service.current.activity.id, f.freeTime);
    });

    test('Default can be switched to (it is off the grid)', () async {
      final defaultId = await roleId(f.db, 'default');
      f.clock.advance(const Duration(minutes: 5));
      await f.service.switchTo(defaultId);
      expect(f.service.current.activity.name, 'Default');
      expect(f.service.current.activity.isDefault, isTrue);
    });

    test('notifies listeners', () async {
      var calls = 0;
      f.service.addListener(() => calls++);
      await f.service.switchTo(f.gaming);
      await f.service.reconcile();
      expect(calls, 2);
    });
  });

  group('durations', () {
    test('session duration is now minus start', () async {
      f.clock.advance(const Duration(hours: 1));
      await f.service.switchTo(f.gaming);
      final later = f.clock.now().add(const Duration(minutes: 42, seconds: 15));
      expect(
        f.service.current.sessionDuration(later),
        const Duration(minutes: 42, seconds: 15),
      );
    });

    test("today's total includes every session of the activity", () async {
      // Gaming 10-11, Study 11-12, Gaming 12-now(13:30)
      f.clock.set(DateTime(2026, 11, 9, 10));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 9, 11));
      await f.service.switchTo(f.study);
      f.clock.set(DateTime(2026, 11, 9, 12));
      await f.service.switchTo(f.gaming);

      final now = DateTime(2026, 11, 9, 13, 30);
      final session = f.service.current;
      expect(session.closedTodayTotal, const Duration(hours: 1));
      expect(session.sessionDuration(now), const Duration(minutes: 90));
      expect(session.todayTotal(now), const Duration(minutes: 150));
    });

    test(
      'seconds from separate sessions add up, nothing is rounded away',
      () async {
        // Three 40.5 s Gaming sessions interleaved with Study.
        f.clock.set(DateTime(2026, 11, 9, 10));
        for (var i = 0; i < 3; i++) {
          await f.service.switchTo(f.gaming);
          f.clock.advance(const Duration(seconds: 40, milliseconds: 500));
          await f.service.switchTo(f.study);
          f.clock.advance(const Duration(minutes: 1));
        }
        await f.service.switchTo(f.gaming);

        final session = f.service.current;
        expect(
          session.closedTodayTotal,
          const Duration(minutes: 2, seconds: 1, milliseconds: 500),
        );
        // 2 more seconds in the current session -> 2m 3.5s total.
        final now = f.clock.now().add(const Duration(seconds: 2));
        expect(
          session.todayTotal(now),
          const Duration(minutes: 2, seconds: 3, milliseconds: 500),
        );
      },
    );

    test("yesterday's time is not part of today's total", () async {
      f.clock.set(DateTime(2026, 11, 9, 22));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 10, 1));
      await f.service.switchTo(f.study);
      f.clock.set(DateTime(2026, 11, 10, 2));
      await f.service.switchTo(f.gaming);

      final session = f.service.current;
      // Only Tuesday 00:00-01:00 counts, not Monday 22:00-24:00.
      expect(session.closedTodayTotal, const Duration(hours: 1));
    });
  });

  group('recovery', () {
    test('restart: a new service on the same file resumes tracking', () async {
      final dir = await Directory.systemTemp.createTemp('tracking_restart');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'app.db');

      final first = await TrackingFixture.create(monday9, path: path);
      await first.service.reconcile();
      first.clock.advance(const Duration(minutes: 20));
      await first.service.switchTo(first.gaming);
      await first.close(); // app killed

      final second = await TrackingFixture.reopen(path, monday9);
      addTearDown(second.close);
      second.clock.set(monday9.add(const Duration(hours: 3)));
      await second.service.reconcile();

      final session = second.service.current;
      expect(session.activity.name, 'Gaming');
      expect(
        session.entry.start,
        isMoment(monday9.add(const Duration(minutes: 20))),
      );
      expect(
        session.sessionDuration(second.clock.now()),
        const Duration(hours: 2, minutes: 40),
      );
    });

    test('suspension on the same day changes no entries', () async {
      await f.service.switchTo(f.gaming);
      f.clock.advance(const Duration(hours: 5));
      await f.service.reconcile(); // resume

      final entries = await expectConsistent();
      expect(entries, hasLength(1));
      expect(
        f.service.current.sessionDuration(f.clock.now()),
        const Duration(hours: 5),
      );
    });

    test('a missing open entry is recovered instead of leaving none', () async {
      await f.db.delete('time_entries');
      await f.service.reconcile();
      await expectConsistent();
      expect(
        f.service.current.activity.isDefault,
        isTrue,
      ); // falls back to Default
    });

    test(
      'clock moved back before session start: no split, no negative',
      () async {
        f.clock.set(DateTime(2026, 11, 9, 12));
        await f.service.switchTo(f.gaming);
        f.clock.set(DateTime(2026, 11, 8, 12)); // a day earlier
        await f.service.reconcile();

        expect(await f.entries(), hasLength(2));
        expect(f.service.current.sessionDuration(f.clock.now()), Duration.zero);

        await f.service.switchTo(f.study);
        final entries = await f.entries();
        final gaming = entries.firstWhere((e) => e.activityId == f.gaming);
        expect(gaming.end, gaming.start, reason: 'closed at its own start');
        expect(entries.where((e) => e.isOpen).single.activityId, f.study);
      },
    );
  });

  group('midnight', () {
    test('23:00 to 02:00 splits into Monday and Tuesday entries', () async {
      f.clock.set(DateTime(2026, 11, 9, 23));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 10, 2));
      await f.service.reconcile();

      final entries = await expectConsistent();
      final gaming = entries.where((e) => e.activityId == f.gaming).toList();
      expect(gaming, hasLength(2));
      expect(gaming[0].start, isMoment(DateTime(2026, 11, 9, 23)));
      expect(gaming[0].end, isMoment(DateTime(2026, 11, 10)));
      expect(gaming[1].start, isMoment(DateTime(2026, 11, 10)));
      expect(gaming[1].isOpen, isTrue);

      final session = f.service.current;
      expect(session.activity.id, f.gaming);
      expect(session.sessionDuration(f.clock.now()), const Duration(hours: 2));
      expect(session.todayTotal(f.clock.now()), const Duration(hours: 2));
    });

    test('switching after a missed midnight splits first', () async {
      f.clock.set(DateTime(2026, 11, 9, 23));
      await f.service.switchTo(f.gaming);
      f.clock.set(DateTime(2026, 11, 10, 2));
      await f.service.switchTo(f.study); // no reconcile in between

      final entries = await expectConsistent();
      expect(
        entries
            .map((e) => (e.activityId, e.start.toLocal(), e.end?.toLocal()))
            .toList(),
        [
          (f.freeTime, monday9, DateTime(2026, 11, 9, 23)),
          (f.gaming, DateTime(2026, 11, 9, 23), DateTime(2026, 11, 10)),
          (f.gaming, DateTime(2026, 11, 10), DateTime(2026, 11, 10, 2)),
          (f.study, DateTime(2026, 11, 10, 2), null),
        ],
      );
    });

    test('several missed midnights create one entry per day', () async {
      // Free Time from Monday 09:00, app next opened Thursday 08:00.
      f.clock.set(DateTime(2026, 11, 12, 8));
      await f.service.reconcile();

      final entries = await expectConsistent();
      expect(entries.map((e) => e.start.toLocal()).toList(), [
        monday9,
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 12),
      ]);
      expect(entries.every((e) => e.activityId == f.freeTime), isTrue);
      final total = entries.fold(
        Duration.zero,
        (sum, e) => sum + e.durationAt(f.clock.now()),
      );
      expect(total, f.clock.now().difference(monday9));
    });

    test('reconciling twice is idempotent', () async {
      f.clock.set(DateTime(2026, 11, 11, 8));
      await f.service.reconcile();
      final first = await f.entries();
      await f.service.reconcile();
      expect((await f.entries()).length, first.length);
    });

    test('dayEnd tells the UI when the next split is due', () {
      expect(f.service.current.dayEnd, DateTime(2026, 11, 10));
    });

    test('exactly at midnight the new day starts', () async {
      f.clock.set(DateTime(2026, 11, 10));
      await f.service.reconcile();
      final entries = await expectConsistent();
      expect(entries.last.start, isMoment(DateTime(2026, 11, 10)));
      expect(f.service.current.sessionDuration(f.clock.now()), Duration.zero);
    });
  });

  group('daylight saving (uses this process\'s local timezone)', () {
    // Local days in 2026 that are not 24 hours long.
    final dstDays = [
      for (
        var d = DateTime(2026);
        d.year == 2026;
        d = DateTime(d.year, d.month, d.day + 1)
      )
        if (localDay(d).duration != const Duration(hours: 24)) d,
    ];
    final skip = dstDays.isEmpty
        ? 'Local timezone has no DST in 2026; run with e.g. TZ=Europe/Berlin'
        : null;

    test('each day entry spans the real length of that day', () async {
      for (final day in dstDays) {
        final g = await TrackingFixture.create(
          DateTime(day.year, day.month, day.day - 1, 12),
        );
        addTearDown(g.close);
        g.clock.set(DateTime(day.year, day.month, day.day + 1, 12));
        await g.service.reconcile();

        final entries = await g.entries();
        expect(entries, hasLength(3));
        final dstEntry = entries[1];
        expect(dstEntry.start, isMoment(startOfLocalDay(day)));
        expect(dstEntry.end, isMoment(nextLocalMidnight(day)));
        expect(
          dstEntry.durationAt(g.clock.now()),
          isNot(const Duration(hours: 24)),
        );
        // No time lost or invented across the whole span.
        final total = entries.fold(
          Duration.zero,
          (sum, e) => sum + e.durationAt(g.clock.now()),
        );
        expect(total, g.clock.now().difference(entries.first.start));
      }
    }, skip: skip);

    test(
      'a session spanning the DST change measures real elapsed time',
      () async {
        for (final day in dstDays) {
          final g = await TrackingFixture.create(startOfLocalDay(day));
          addTearDown(g.close);
          await g.service.reconcile();
          final evening = DateTime(day.year, day.month, day.day, 20);
          expect(
            g.service.current.sessionDuration(evening),
            evening.difference(startOfLocalDay(day)),
          );
          expect(
            evening.difference(startOfLocalDay(day)),
            isNot(const Duration(hours: 20)),
          );
        }
      },
      skip: skip,
    );
  });

  test('repository close refuses an already-closed entry', () async {
    f.clock.advance(const Duration(minutes: 1));
    await f.service.switchTo(f.gaming);
    final closed = (await f.entries()).first;
    await expectLater(
      TimeEntryRepository(f.db).close(closed.id, f.clock.now()),
      throwsStateError,
    );
  });
}
