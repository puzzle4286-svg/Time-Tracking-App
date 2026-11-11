import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/activities/activity_service.dart';
import 'package:time_tracker/services/history/history_service.dart';

import '../../support/matchers.dart';
import '../../support/timeline_fixture.dart';
import '../../support/tracking_fixture.dart';

void main() {
  late TrackingFixture f;
  late ActivityService activities;

  setUp(() async {
    f = await mondayTimeline();
    activities = ActivityService(f.db, f.clock, f.service);
    await activities.load();
  });
  tearDown(() => f.close());

  Future<List<String>> mondayNames() async => [
    for (final e in await HistoryService(f.db).entriesForDay(mon(12)))
      e.activity.name,
  ];

  test(
    'keep under a new name: history keeps its times and gets the name',
    () async {
      final before = await spans(f);
      await activities.delete(
        f.gaming,
        history: const KeepUnderName('Old games'),
      );
      expect(activities.byId(f.gaming), isNull);
      expect(activities.atPosition(2), isNull);
      expect(await spans(f), before);
      expect(await mondayNames(), [
        'Free Time',
        'Old games',
        'Study',
        'Free Time',
      ]);
    },
  );

  test('move to another activity', () async {
    await activities.delete(f.gaming, history: MoveToActivity(f.study));
    final s = await spans(f);
    expect(s[1], (f.study, mon(10), mon(12)));
    expect(await activities.entryCount(f.gaming), 0);
  });

  test('mark as Unavailable', () async {
    await activities.delete(f.gaming, history: const MarkUnavailable());
    expect(await mondayNames(), [
      'Free Time',
      'Unavailable',
      'Study',
      'Free Time',
    ]);
  });

  test('history choice is required when there are entries', () async {
    await expectLater(activities.delete(f.gaming), throwsArgumentError);
    expect(activities.byId(f.gaming), isNotNull);
  });

  test('an activity without entries is simply removed', () async {
    final reading = await activities.create(
      position: 4,
      name: 'Reading',
      color: 0,
    );
    await activities.delete(reading.id);
    expect(activities.atPosition(4), isNull);
  });

  test('deleting the active activity requires a successor', () async {
    // Free Time is running.
    await expectLater(
      activities.delete(f.freeTime, history: const MarkUnavailable()),
      throwsArgumentError,
    );
    await activities.delete(
      f.freeTime,
      history: const MarkUnavailable(),
      newActiveId: f.study,
    );
    expect(f.service.current.activity.id, f.study);
    expect(f.service.current.entry.start, isMoment(mon(15)));
    final open = (await f.entries()).where((e) => e.isOpen);
    expect(open, hasLength(1));
  });

  test(
    'invalid choices change nothing, not even the active activity',
    () async {
      final before = await spans(f);
      await expectLater(
        activities.delete(
          f.freeTime,
          history: const KeepUnderName('   '),
          newActiveId: f.study,
        ),
        throwsArgumentError,
      );
      await expectLater(
        activities.delete(f.gaming, history: MoveToActivity(f.gaming)),
        throwsArgumentError,
      );
      expect(await spans(f), before);
      expect(f.service.current.activity.id, f.freeTime);
    },
  );

  test('a freed position can be set up again', () async {
    await activities.delete(f.gaming, history: const MarkUnavailable());
    final again = await activities.create(position: 2, name: 'New', color: 0);
    expect(activities.atPosition(2)!.id, again.id);
  });
}
