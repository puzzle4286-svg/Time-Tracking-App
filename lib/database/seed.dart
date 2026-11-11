import 'package:sqflite/sqflite.dart';

import '../models/activity_colors.dart';
import '../repositories/activity_repository.dart';
import '../repositories/time_entry_repository.dart';

const String initialActivityName = 'Free Time';
const String unavailableActivityName = 'Unavailable';

/// First-launch setup: creates "Free Time" at position 1, the hidden system
/// "Unavailable" activity, and starts tracking Free Time at [now].
///
/// Does nothing if activities already exist, so it is safe to call on every
/// launch. Runs in one transaction: either everything is created or nothing.
Future<void> ensureSeeded(Database db, DateTime now) {
  return db.transaction((txn) async {
    final activities = ActivityRepository(txn);
    if (await activities.count() > 0) return;

    final freeTimeId = await activities.insert(
      name: initialActivityName,
      color: activityColors.first,
      position: 1,
      createdAt: now,
    );
    await activities.insert(
      name: unavailableActivityName,
      color: unavailableColor,
      position: null,
      createdAt: now,
      isSystem: true,
    );
    await TimeEntryRepository(txn).insert(activityId: freeTimeId, start: now);
  });
}
