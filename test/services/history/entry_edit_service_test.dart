import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/time_entry.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';

import '../../support/matchers.dart';
import '../../support/timeline_fixture.dart';
import '../../support/tracking_fixture.dart';

void main() {
  late TrackingFixture f;
  late EntryEditService edits;

  setUp(() async {
    f = await mondayTimeline();
    edits = EntryEditService(f.db, f.clock, f.service);
  });
  tearDown(() => f.close());

  Future<TimeEntry> entryOf(int activityId, DateTime start) async =>
      (await f.entries()).firstWhere(
        (e) => e.activityId == activityId && e.start.isAtSameMomentAs(start),
      );

  /// No overlaps, exactly one open entry, and it is the last one.
  Future<void> expectConsistent() async {
    final entries = await f.entries();
    expect(entries.where((e) => e.isOpen), hasLength(1));
    expect(entries.last.isOpen, isTrue);
    for (var i = 1; i < entries.length; i++) {
      expect(
        entries[i].start.isBefore(entries[i - 1].end!),
        isFalse,
        reason: 'entry $i overlaps the previous one',
      );
    }
  }

  group('change activity', () {
    test('reassigns one entry and keeps its times', () async {
      final study = await entryOf(f.study, mon(12));
      await edits.changeActivity(study.id, f.gaming);
      expect(await spans(f), [
        (f.freeTime, mon(9), mon(10)),
        (f.gaming, mon(10), mon(12)),
        (f.gaming, mon(12), mon(13)),
        (f.freeTime, mon(13), null),
      ]);
    });

    test('changing the running entry changes the current activity', () async {
      final open = await entryOf(f.freeTime, mon(13));
      await edits.changeActivity(open.id, f.study);
      expect(f.service.current.activity.id, f.study);
      expect(f.service.current.entry.start, isMoment(open.start));
    });

    test('refuses the system activity', () async {
      final system =
          (await f.db.query('activities', where: 'is_system = 1')).single['id']!
              as int;
      final study = await entryOf(f.study, mon(12));
      await expectLater(
        edits.changeActivity(study.id, system),
        throwsA(isA<EditException>()),
      );
    });
  });

  group('change start / end', () {
    test('a dry run reports effects and writes nothing', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      final before = await spans(f);
      final effects = await edits.retime(
        gaming.id,
        start: mon(10),
        end: mon(12, 30),
        apply: false,
      );
      expect(effects.single.kind, EffectKind.shortened);
      expect(effects.single.activity.name, 'Study');
      expect(effects.single.newStart, mon(12, 30));
      expect(await spans(f), before);
    });

    test('extending the end shortens the next entry', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await edits.retime(
        gaming.id,
        start: mon(10),
        end: mon(12, 30),
        apply: true,
      );
      expect(await spans(f), [
        (f.freeTime, mon(9), mon(10)),
        (f.gaming, mon(10), mon(12, 30)),
        (f.study, mon(12, 30), mon(13)),
        (f.freeTime, mon(13), null),
      ]);
      await expectConsistent();
    });

    test(
      'fully covered entries are removed, the running one shortened',
      () async {
        final gaming = await entryOf(f.gaming, mon(10));
        final effects = await edits.retime(
          gaming.id,
          start: mon(10),
          end: mon(13, 30),
          apply: true,
        );
        expect(effects.map((e) => e.kind), [
          EffectKind.removed,
          EffectKind.shortened,
        ]);
        expect(await spans(f), [
          (f.freeTime, mon(9), mon(10)),
          (f.gaming, mon(10), mon(13, 30)),
          (f.freeTime, mon(13, 30), null),
        ]);
        await expectConsistent();
      },
    );

    test('shrinking hands the freed time to the adjacent neighbour', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      final effects = await edits.retime(
        gaming.id,
        start: mon(10, 30),
        end: mon(11, 30),
        apply: true,
      );
      expect(effects.map((e) => e.kind), [
        EffectKind.extended,
        EffectKind.extended,
      ]);
      expect(await spans(f), [
        (f.freeTime, mon(9), mon(10, 30)),
        (f.gaming, mon(10, 30), mon(11, 30)),
        (f.study, mon(11, 30), mon(13)),
        (f.freeTime, mon(13), null),
      ]);
      await expectConsistent();
    });

    test('moving an entry inside another splits that one around it', () async {
      final study = await entryOf(f.study, mon(12));
      final effects = await edits.retime(
        study.id,
        start: mon(10, 30),
        end: mon(11),
        apply: true,
      );
      expect(effects.map((e) => e.kind), contains(EffectKind.splitAround));
      expect(await spans(f), [
        (f.freeTime, mon(9), mon(10)),
        (f.gaming, mon(10), mon(10, 30)),
        (f.study, mon(10, 30), mon(11)),
        (f.gaming, mon(11), mon(12)),
        // The freed 12–13 goes to the following entry, never overlapping.
        (f.freeTime, mon(12), null),
      ]);
      await expectConsistent();
    });

    test('the running entry can move its start, not its end', () async {
      final open = await entryOf(f.freeTime, mon(13));
      await edits.retime(
        open.id,
        start: mon(12, 30),
        end: mon(14),
        apply: true,
      );
      expect((await spans(f)).last, (f.freeTime, mon(12, 30), null));
      expect((await spans(f))[2], (f.study, mon(12), mon(12, 30)));
      await expectConsistent();
    });

    test('rejects invalid bounds', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      Future<void> bad(DateTime s, DateTime e) => expectLater(
        edits.retime(gaming.id, start: s, end: e, apply: false),
        throwsA(isA<EditException>()),
      );
      await bad(mon(11), mon(11)); // zero length
      await bad(mon(11), mon(10)); // negative
      await bad(mon(10), mon(16)); // future
      await bad(mon(10), mon(15)); // would swallow the running entry
    });

    test('an entry extended past midnight is split per day', () async {
      f.clock.set(DateTime(2026, 11, 10, 9));
      await f.service.reconcile(); // Free Time 13:00 -> midnight -> open
      final study = await entryOf(f.study, mon(12));
      await edits.retime(
        study.id,
        start: mon(12),
        end: DateTime(2026, 11, 10, 1),
        apply: true,
      );
      final s = await spans(f);
      expect(s, contains((f.study, mon(12), DateTime(2026, 11, 10))));
      expect(
        s,
        contains((f.study, DateTime(2026, 11, 10), DateTime(2026, 11, 10, 1))),
      );
      expect(s.last, (f.freeTime, DateTime(2026, 11, 10, 1), null));
      await expectConsistent();
    });
  });

  group('delete', () {
    test('options depend on adjacent neighbours', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      final o = await edits.deleteOptions(gaming.id);
      expect(o.available, [
        DeleteFill.previous,
        DeleteFill.following,
        DeleteFill.split,
      ]);
      expect(o.previous!.activity.name, 'Free Time');
      expect(o.following!.activity.name, 'Study');

      final first = await entryOf(f.freeTime, mon(9));
      expect((await edits.deleteOptions(first.id)).available, [
        DeleteFill.following,
      ]);
      final open = await entryOf(f.freeTime, mon(13));
      expect((await edits.deleteOptions(open.id)).available, [
        DeleteFill.previous,
      ]);
    });

    test('fill with the previous activity', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await edits.delete(gaming.id, DeleteFill.previous);
      expect((await spans(f)).first, (f.freeTime, mon(9), mon(12)));
      await expectConsistent();
    });

    test('fill with the following activity', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await edits.delete(gaming.id, DeleteFill.following);
      expect((await spans(f))[1], (f.study, mon(10), mon(13)));
      await expectConsistent();
    });

    test('split evenly between both', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await edits.delete(gaming.id, DeleteFill.split);
      expect((await spans(f)).take(2).toList(), [
        (f.freeTime, mon(9), mon(11)),
        (f.study, mon(11), mon(13)),
      ]);
      await expectConsistent();
    });

    test('deleting the running entry resumes the previous activity', () async {
      final open = await entryOf(f.freeTime, mon(13));
      await edits.delete(open.id, DeleteFill.previous);
      expect((await spans(f)).last, (f.study, mon(12), null));
      expect(f.service.current.activity.id, f.study);
      await expectConsistent();
    });

    test('leave empty only when nothing is adjacent', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await expectLater(
        edits.delete(gaming.id, DeleteFill.leaveEmpty),
        throwsA(isA<EditException>()),
      );
      // Isolate an entry with gaps on both sides.
      final first = await entryOf(f.freeTime, mon(9));
      await f.db.update(
        'time_entries',
        {'end_utc': mon(9, 30).toUtc().microsecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [first.id],
      );
      await f.db.update(
        'time_entries',
        {'start_utc': mon(9, 10).toUtc().microsecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [first.id],
      );
      expect((await edits.deleteOptions(first.id)).available, [
        DeleteFill.leaveEmpty,
      ]);
      await edits.delete(first.id, DeleteFill.leaveEmpty);
      expect((await f.entries()).length, 3);
    });

    test('filling across midnight keeps one entry per day', () async {
      // Free Time from 13:00 Monday runs into Tuesday 09:00.
      f.clock.set(DateTime(2026, 11, 10, 9));
      await f.service.reconcile();
      f.clock.set(DateTime(2026, 11, 10, 10));
      await f.service.switchTo(f.gaming);
      final tuesdayFree = await entryOf(f.freeTime, DateTime(2026, 11, 10));
      // Delete Tuesday's Free Time and fill with the following Gaming:
      // Gaming then starts at Tuesday midnight, not Monday.
      await edits.delete(tuesdayFree.id, DeleteFill.following);
      expect((await spans(f)).last, (f.gaming, DateTime(2026, 11, 10), null));
      await expectConsistent();
    });
  });

  group('split', () {
    test('splits a closed entry into two of the same activity', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      await edits.split(gaming.id, mon(11, 15));
      expect((await spans(f)).sublist(1, 3), [
        (f.gaming, mon(10), mon(11, 15)),
        (f.gaming, mon(11, 15), mon(12)),
      ]);
      await expectConsistent();
    });

    test('splitting the running entry keeps it running', () async {
      final open = await entryOf(f.freeTime, mon(13));
      await edits.split(open.id, mon(14));
      expect((await spans(f)).last, (f.freeTime, mon(14), null));
      await expectConsistent();
    });

    test('the split point must lie inside the entry', () async {
      final gaming = await entryOf(f.gaming, mon(10));
      for (final at in [mon(10), mon(12), mon(9)]) {
        await expectLater(
          edits.split(gaming.id, at),
          throwsA(isA<EditException>()),
        );
      }
    });
  });

  test('every edit notifies listeners and refreshes tracking', () async {
    var notified = 0;
    edits.addListener(() => notified++);
    final gaming = await entryOf(f.gaming, mon(10));
    await edits.split(gaming.id, mon(11));
    await edits.changeActivity(gaming.id, f.study);
    expect(notified, 2);
  });
}
