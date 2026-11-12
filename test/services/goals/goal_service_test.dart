import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/models/goal.dart';
import 'package:time_tracker/services/goals/goal_service.dart';
import 'package:time_tracker/services/history/entry_edit_service.dart';

import '../../support/test_database.dart';
import '../../support/timeline_fixture.dart';
import '../../support/tracking_fixture.dart';

void main() {
  late TrackingFixture f;
  late GoalService goals;

  // Monday: Free Time 09–10 · Gaming 10–12 · Study 12–13 · Free Time 13–now(15)
  setUp(() async {
    f = await mondayTimeline();
    goals = GoalService(f.db, f.clock);
  });
  tearDown(() => f.close());

  GoalDraft daily({Duration? min, Duration? max}) => GoalDraft(
    unit: GoalUnit.day,
    length: 1,
    anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
    minimum: min,
    maximum: max,
  );

  test('multiple independent goals per activity', () async {
    await goals.create(f.gaming, daily(min: const Duration(hours: 1)));
    await goals.create(
      f.gaming,
      GoalDraft(
        unit: GoalUnit.week,
        length: 1,
        anchor: GoalAnchor.fromLocal(DateTime(2026, 11, 9)),
        maximum: const Duration(hours: 10),
      ),
    );
    await goals.create(f.gaming, daily(max: const Duration(hours: 3)));
    expect(await goals.goalsFor(f.gaming), hasLength(3));
    expect(await goals.goalsFor(f.study), isEmpty);
  });

  test('round-trips every field', () async {
    final g = await goals.create(
      f.study,
      GoalDraft(
        name: '  Deep work ',
        unit: GoalUnit.month,
        length: 2,
        anchor: const GoalAnchor(
          year: 2026,
          month: 1,
          day: 31,
          minuteOfDay: 450,
        ),
        minimum: const Duration(hours: 40, seconds: 1),
        maximum: const Duration(hours: 80),
        enabled: false,
      ),
    );
    expect(g.name, 'Deep work');
    expect(g.unit, GoalUnit.month);
    expect(g.length, 2);
    expect(g.anchor.hour, 7);
    expect(g.anchor.minute, 30);
    expect(g.minimum, const Duration(hours: 40, seconds: 1));
    expect(g.enabled, isFalse);
  });

  test('validation', () async {
    Future<void> bad(GoalDraft d) =>
        expectLater(goals.create(f.gaming, d), throwsArgumentError);
    await bad(daily()); // no target
    await bad(
      daily(min: const Duration(hours: 5), max: const Duration(hours: 1)),
    );
    await bad(daily(min: Duration.zero));
    await bad(
      GoalDraft(
        unit: GoalUnit.day,
        length: 0,
        anchor: GoalAnchor.fromLocal(DateTime(2026)),
        minimum: const Duration(hours: 1),
      ),
    );
    // Not for Default.
    await expectLater(
      goals.create(
        await roleId(f.db, 'default'),
        daily(min: const Duration(hours: 1)),
      ),
      throwsArgumentError,
    );
  });

  test('the database enforces the same constraints', () async {
    expect(
      () => f.db.insert('goals', {
        'activity_id': f.gaming,
        'period_unit': 'day',
        'period_length': 1,
        'anchor_year': 2026,
        'anchor_month': 1,
        'anchor_day': 1,
        'anchor_minute': 0,
        'created_at': 0,
      }),
      throwsA(isA<DatabaseException>()), // neither min nor max
    );
  });

  test('progress follows recorded time, including history edits', () async {
    final g = await goals.create(
      f.gaming,
      daily(min: const Duration(hours: 3)),
    );
    var p = await goals.progress(g);
    expect(p.tracked, const Duration(hours: 2));
    expect(p.minimumReached, isFalse);

    // Change Study 12–13 to Gaming: progress updates without any stored
    // statistic.
    final study = (await f.entries()).firstWhere(
      (e) => e.activityId == f.study,
    );
    await EntryEditService(
      f.db,
      f.clock,
      f.service,
    ).changeActivity(study.id, f.gaming);
    p = await goals.progress(g);
    expect(p.tracked, const Duration(hours: 3));
    expect(p.minimumReached, isTrue);
  });

  test('update, delete and listeners', () async {
    var notified = 0;
    goals.addListener(() => notified++);
    final g = await goals.create(
      f.gaming,
      daily(min: const Duration(hours: 1)),
    );
    await goals.update(g.id, daily(max: const Duration(hours: 2)));
    final updated = (await goals.goalsFor(f.gaming)).single;
    expect(updated.minimum, isNull);
    expect(updated.maximum, const Duration(hours: 2));
    await goals.delete(g.id);
    expect(await goals.goalsFor(f.gaming), isEmpty);
    expect(notified, 3);
  });
}
