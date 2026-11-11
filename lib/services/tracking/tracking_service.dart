import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import 'durations.dart';
import 'entry_normalization.dart';
import 'time_range.dart';

/// Snapshot of what is being tracked right now.
///
/// Durations are computed from timestamps on demand; nothing here counts
/// time by itself.
class ActiveSession {
  const ActiveSession({
    required this.activity,
    required this.entry,
    required this.closedTodayTotal,
  });

  final Activity activity;

  /// The open time entry (its start is the session start).
  final TimeEntry entry;

  /// Today's time for [activity] from entries that are already closed.
  final Duration closedTodayTotal;

  /// Length of the current session. Zero if the device clock is earlier than
  /// the session start (e.g. the user moved the clock back).
  Duration sessionDuration(DateTime now) {
    final d = now.difference(entry.start);
    return d.isNegative ? Duration.zero : d;
  }

  /// Total time on [activity] today, including the current session.
  Duration todayTotal(DateTime now) => closedTodayTotal + sessionDuration(now);

  /// When the current daily entry has to be split. The UI should call
  /// [TrackingService.reconcile] once `now` reaches this.
  DateTime get dayEnd => nextLocalMidnight(entry.start);
}

/// Owns the tracking state: exactly one open time entry at all times.
///
/// Every operation runs in one database transaction and first reconciles the
/// stored state with the current time, so correctness never depends on the
/// app having been running (e.g. at midnight).
class TrackingService extends ChangeNotifier {
  TrackingService(this._db, this._clock);

  final Database _db;
  final Clock _clock;

  ActiveSession? _current;

  /// The current session. Available after the first [reconcile].
  ActiveSession get current {
    final session = _current;
    if (session == null) {
      throw StateError('TrackingService.reconcile() has not run yet.');
    }
    return session;
  }

  /// Brings stored state up to date with the current time: splits the open
  /// entry at every local midnight that has passed since it started. Call on
  /// launch, on resume, and when a day ends while the app is visible.
  Future<void> reconcile() async {
    final now = _clock.now();
    _current = await _db.transaction((txn) async {
      await _reconcileIn(txn, now);
      return _loadSession(txn, now);
    });
    notifyListeners();
  }

  /// Ends the current entry and starts [activityId] at the current time,
  /// atomically. Selecting the already-active activity does nothing.
  Future<void> switchTo(int activityId) async {
    final now = _clock.now();
    _current = await _db.transaction((txn) async {
      final open = await _reconcileIn(txn, now);
      if (open.activityId != activityId) {
        final target = await ActivityRepository(txn).byId(activityId);
        if (target == null || target.isDeleted || target.isSystem) {
          throw ArgumentError.value(
            activityId,
            'activityId',
            'Not a live activity',
          );
        }
        final entries = TimeEntryRepository(txn);
        if (now.isAtSameMomentAs(open.start)) {
          // Zero-length: leave no empty entry behind.
          await entries.delete(open.id);
        } else {
          // If the device clock was moved before the session start, the
          // entry is closed at its own start rather than given a negative
          // duration; it stays visible in history.
          await entries.close(
            open.id,
            now.isAfter(open.start) ? now : open.start,
          );
        }
        await entries.insert(activityId: activityId, start: now);
      }
      return _loadSession(txn, now);
    });
    notifyListeners();
  }

  /// Returns the (possibly new) open entry after splitting at midnights.
  Future<TimeEntry> _reconcileIn(Transaction txn, DateTime now) async {
    final entries = TimeEntryRepository(txn);
    var open = await entries.openEntry() ?? await _recoverOpenEntry(txn, now);

    open = await splitAtLocalMidnights(entries, open, now);
    return open;
  }

  /// Safety net: the schema and transactions should make this unreachable,
  /// but if no entry is open, start one rather than leave nothing active.
  Future<TimeEntry> _recoverOpenEntry(Transaction txn, DateTime now) async {
    debugPrint('TrackingService: no open entry found; recovering.');
    final live = await ActivityRepository(txn).liveActivities();
    if (live.isEmpty) {
      throw StateError('No live activity exists to track.');
    }
    final id = await TimeEntryRepository(
      txn,
    ).insert(activityId: live.first.id, start: now);
    return TimeEntry(id: id, activityId: live.first.id, start: now, end: null);
  }

  Future<ActiveSession> _loadSession(Transaction txn, DateTime now) async {
    final entries = TimeEntryRepository(txn);
    final open = (await entries.openEntry())!;
    final activity = (await ActivityRepository(txn).byId(open.activityId))!;
    final today = localDay(open.start);
    final todays = await entries.overlapping(today.start, today.end);
    return ActiveSession(
      activity: activity,
      entry: open,
      closedTodayTotal: trackedInRange(
        todays.where((e) => !e.isOpen),
        today,
        now,
        activityId: activity.id,
      ),
    );
  }
}
