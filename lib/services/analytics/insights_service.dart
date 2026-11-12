import 'package:sqflite/sqflite.dart';

import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import 'comparison.dart';
import 'distribution.dart';
import 'insight_period.dart';

/// Everything the Insights screen shows for one selected period.
class InsightsData {
  const InsightsData({
    required this.period,
    required this.distribution,
    required this.comparison,
  });

  final InsightPeriod period;
  final List<ActivityShare> distribution;

  /// Null for "all time" (there is no previous period).
  final PeriodComparison? comparison;
}

/// Loads entries and computes Insights. All statistics are derived from
/// time entries on demand; nothing is stored.
class InsightsService {
  const InsightsService(this._db, this._clock);

  final DatabaseExecutor _db;
  final Clock _clock;

  Future<InsightsData> load(InsightPeriod period) async {
    final now = _clock.now();
    final entries = TimeEntryRepository(_db);
    final activities = await ActivityRepository(_db).allById();
    final first = await entries.earliestStart();

    final range = period.range(now: now, firstEntry: first);
    final hasPrevious = period.unit != InsightUnit.all;
    final previous = hasPrevious ? period.previous.range(now: now) : null;
    final loaded = await entries.overlapping(
      previous?.start ?? range.start,
      range.end,
    );

    return InsightsData(
      period: period,
      distribution: activityDistribution(loaded, range, now, activities),
      comparison: previous == null
          ? null
          : comparePeriods(
              entries: loaded,
              current: range,
              previous: previous,
              now: now,
              activities: activities,
            ),
    );
  }
}
