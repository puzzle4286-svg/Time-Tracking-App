import 'package:sqflite/sqflite.dart';

import '../models/activity.dart';
import '../models/activity_colors.dart';
import '../repositories/activity_repository.dart';
import '../repositories/time_entry_repository.dart';

const String defaultActivityName = 'Default';
const String unavailableActivityName = 'Unavailable';

/// First-launch setup: creates the built-in "Default" and "Unavailable"
/// activities and starts tracking Default at [now]. All eight grid slots
/// start empty.
///
/// Does nothing if activities already exist, so it is safe to call on every
/// launch. Runs in one transaction: either everything is created or nothing.
Future<void> ensureSeeded(Database db, DateTime now) {
  return db.transaction((txn) async {
    final activities = ActivityRepository(txn);
    if (await activities.count() > 0) return;

    final defaultId = await activities.insert(
      name: defaultActivityName,
      color: defaultActivityColor,
      position: null,
      createdAt: now,
      role: SystemRole.defaultActivity,
    );
    await activities.insert(
      name: unavailableActivityName,
      color: unavailableColor,
      position: null,
      createdAt: now,
      role: SystemRole.unavailable,
    );
    await TimeEntryRepository(txn).insert(activityId: defaultId, start: now);
  });
}
