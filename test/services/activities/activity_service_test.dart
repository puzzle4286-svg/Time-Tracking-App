import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/models/activity_colors.dart';
import 'package:time_tracker/services/activities/activity_service.dart';

import '../../support/tracking_fixture.dart';

void main() {
  late TrackingFixture f;
  late ActivityService service;

  setUp(() async {
    f = await TrackingFixture.create(DateTime(2026, 11, 9, 9));
    service = ActivityService(f.db, f.clock, f.service);
    await service.load();
  });
  tearDown(() => f.close());

  test('loads live activities in position order, without system ones', () {
    expect(service.live.map((a) => a.name), ['Free Time', 'Gaming', 'Study']);
    expect(service.atPosition(4), isNull);
  });

  test('creates an activity in an empty position', () async {
    final created = await service.create(
      position: 5,
      name: '  Reading ',
      color: activityColors[3],
    );
    expect(created.name, 'Reading');
    expect(created.position, 5);
    expect(service.atPosition(5)!.id, created.id);
  });

  test('refuses an occupied or out-of-range position', () async {
    await expectLater(
      service.create(position: 1, name: 'X', color: 0),
      throwsStateError,
    );
    await expectLater(
      service.create(position: 9, name: 'X', color: 0),
      throwsArgumentError,
    );
  });

  test('validates names', () async {
    expect(ActivityService.validateName(''), isNotNull);
    expect(ActivityService.validateName('   '), isNotNull);
    expect(ActivityService.validateName('a' * 31), isNotNull);
    expect(ActivityService.validateName('Study'), isNull);
    await expectLater(
      service.create(position: 4, name: ' ', color: 0),
      throwsArgumentError,
    );
  });

  test('rename keeps the id, so history follows', () async {
    await f.service.reconcile();
    f.clock.advance(const Duration(hours: 1));
    await f.service.switchTo(f.gaming);

    await service.update(f.gaming, name: 'Games', color: activityColors[4]);
    expect(service.byId(f.gaming)!.name, 'Games');
    expect(service.byId(f.gaming)!.color, activityColors[4]);
    final entries = await f.entries();
    expect(entries.last.activityId, f.gaming);
  });

  test('suggests a colour not used by live activities', () async {
    await service.update(
      f.freeTime,
      name: 'Free Time',
      color: activityColors[0],
    );
    await service.update(f.gaming, name: 'Gaming', color: activityColors[1]);
    await service.update(f.study, name: 'Study', color: activityColors[2]);
    expect(service.suggestColor(), activityColors[3]);
  });
}
