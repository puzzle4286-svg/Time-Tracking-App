import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import '../tracking/day_split.dart';
import '../tracking/tracking_service.dart';

/// An edit that cannot be applied, with a message for the user.
class EditException implements Exception {
  const EditException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum EffectKind { shortened, extended, removed, splitAround }

/// How an edit changes an entry other than the one being edited. Shown to
/// the user for confirmation before anything is written.
class EntryEffect {
  const EntryEffect({
    required this.kind,
    required this.entry,
    required this.activity,
    this.newStart,
    this.newEnd,
  });

  final EffectKind kind;

  /// The entry as it is now.
  final TimeEntry entry;
  final Activity activity;

  /// The entry's bounds after the edit (for shortened / extended).
  final DateTime? newStart;
  final DateTime? newEnd;
}

/// Ways to fill the time of a deleted entry.
enum DeleteFill {
  /// The previous (adjacent) entry is extended over the gap.
  previous,

  /// The following (adjacent) entry is extended back over the gap.
  following,

  /// Both neighbours meet in the middle of the gap.
  split,

  /// The time stays untracked. Only offered when no neighbour is adjacent.
  leaveEmpty,
}

/// Neighbours of an entry that touch it exactly, and the fill options.
class DeleteOptions {
  const DeleteOptions({
    required this.previous,
    required this.following,
    required this.available,
  });

  final ({TimeEntry entry, Activity activity})? previous;
  final ({TimeEntry entry, Activity activity})? following;
  final List<DeleteFill> available;
}

/// Edits of historical time entries. Every edit is one transaction; entries
/// are re-split at local midnights afterwards, and tracking is reconciled so
/// the current session and all statistics follow.
class EntryEditService extends ChangeNotifier {
  EntryEditService(this._db, this._clock, this._tracking);

  final Database _db;
  final Clock _clock;
  final TrackingService _tracking;

  // ---- Change activity ----------------------------------------------------

  Future<void> changeActivity(int entryId, int activityId) async {
    await _db.transaction((txn) async {
      final target = await ActivityRepository(txn).byId(activityId);
      if (target == null || target.isDeleted || target.isSystem) {
        throw const EditException('Choose an activity from the grid.');
      }
      await _entry(txn, entryId);
      await TimeEntryRepository(txn).setActivity(entryId, activityId);
    });
    await _changed();
  }

  // ---- Change start / end ---------------------------------------------------

  /// Changes an entry's bounds. With [apply] false nothing is written and
  /// the effects on other entries are returned for confirmation; with
  /// [apply] true the same plan is recomputed and applied atomically.
  ///
  /// Rules: overlapped entries are shortened, split around the edited entry,
  /// or removed if fully covered. When the edited entry shrinks, an adjacent
  /// neighbour grows into the freed time, so no tracked time disappears.
  /// The end of the running entry cannot be set (it is "now").
  Future<List<EntryEffect>> retime(
    int entryId, {
    required DateTime start,
    DateTime? end,
    required bool apply,
  }) async {
    final effects = await _db.transaction((txn) async {
      final plan = await _planRetime(txn, entryId, start, end);
      if (apply) await _applyPlan(txn, plan);
      return plan.effects;
    });
    if (apply) await _changed();
    return effects;
  }

  Future<_Plan> _planRetime(
    Transaction txn,
    int entryId,
    DateTime start,
    DateTime? requestedEnd,
  ) async {
    final entries = TimeEntryRepository(txn);
    final activities = await ActivityRepository(txn).allById();
    final now = _clock.now();
    final e = await _entry(txn, entryId);
    final end = e.isOpen ? null : requestedEnd ?? e.end;
    final effectiveEnd = end ?? now;

    if (start.isAfter(now)) {
      throw const EditException('The start cannot be in the future.');
    }
    if (end != null && end.isAfter(now)) {
      throw const EditException('The end cannot be in the future.');
    }
    if (!start.isBefore(effectiveEnd)) {
      throw const EditException('The start must be before the end.');
    }

    final plan = _Plan();
    EntryEffect effect(
      EffectKind kind,
      TimeEntry o, [
      DateTime? s,
      DateTime? t,
    ]) => EntryEffect(
      kind: kind,
      entry: o,
      activity: activities[o.activityId]!,
      newStart: s,
      newEnd: t,
    );

    // Shrinking: adjacent neighbours take over the freed part of the old
    // range (old minus new), never more, so they cannot overlap anything.
    final oldEnd = e.end ?? now;
    if (start.isAfter(e.start)) {
      final prev = await entries.endingAt(e.start, excludeId: e.id);
      if (prev != null) {
        final to = start.isBefore(oldEnd) ? start : oldEnd;
        plan.update(prev.id, prev.start, to);
        plan.effects.add(effect(EffectKind.extended, prev, prev.start, to));
      }
    }
    if (end != null && end.isBefore(oldEnd)) {
      final next = await entries.startingAt(oldEnd, excludeId: e.id);
      if (next != null) {
        final from = end.isAfter(e.start) ? end : e.start;
        plan.update(next.id, from, next.end);
        plan.effects.add(effect(EffectKind.extended, next, from, next.end));
      }
    }

    // Growing: resolve overlaps with other entries.
    for (final o in await entries.overlapping(start, effectiveEnd)) {
      if (o.id == e.id) continue;
      final oEnd = o.end ?? now;
      final covered = !o.start.isBefore(start) && !oEnd.isAfter(effectiveEnd);
      if (covered) {
        if (o.isOpen) {
          throw const EditException(
            'This would remove the running session. Switch activity instead.',
          );
        }
        plan.remove(o.id);
        plan.effects.add(effect(EffectKind.removed, o));
      } else if (o.start.isBefore(start) && oEnd.isAfter(effectiveEnd)) {
        // The edited entry now lies inside `o`: keep both outer parts.
        plan.update(o.id, o.start, start);
        plan.insert(o.activityId, effectiveEnd, o.end);
        plan.effects.add(effect(EffectKind.splitAround, o));
      } else if (o.start.isBefore(start)) {
        plan.update(o.id, o.start, start);
        plan.effects.add(effect(EffectKind.shortened, o, o.start, start));
      } else {
        plan.update(o.id, effectiveEnd, o.end);
        plan.effects.add(effect(EffectKind.shortened, o, effectiveEnd, o.end));
      }
    }

    plan.update(e.id, start, end);
    return plan;
  }

  // ---- Delete ------------------------------------------------------------

  /// Which fill options exist for deleting [entryId].
  Future<DeleteOptions> deleteOptions(int entryId) async {
    final entries = TimeEntryRepository(_db);
    final activities = await ActivityRepository(_db).allById();
    final e = await _entry(_db, entryId);
    final prev = await entries.endingAt(e.start, excludeId: e.id);
    final next = e.isOpen
        ? null
        : await entries.startingAt(e.end!, excludeId: e.id);
    return DeleteOptions(
      previous: prev == null
          ? null
          : (entry: prev, activity: activities[prev.activityId]!),
      following: next == null
          ? null
          : (entry: next, activity: activities[next.activityId]!),
      available: [
        if (prev != null) DeleteFill.previous,
        if (next != null) DeleteFill.following,
        if (prev != null && next != null) DeleteFill.split,
        // Leaving a gap is only allowed when nothing can fill it, and never
        // for the running entry (something must always be active).
        if (prev == null && next == null && !e.isOpen) DeleteFill.leaveEmpty,
      ],
    );
  }

  /// Deletes an entry and fills its time as chosen. Deleting the running
  /// entry with [DeleteFill.previous] resumes the previous activity.
  Future<void> delete(int entryId, DeleteFill fill) async {
    final now = _clock.now();
    await _db.transaction((txn) async {
      final entries = TimeEntryRepository(txn);
      final e = await _entry(txn, entryId);
      final prev = await entries.endingAt(e.start, excludeId: e.id);
      final next = e.isOpen
          ? null
          : await entries.startingAt(e.end!, excludeId: e.id);

      final ok = switch (fill) {
        DeleteFill.previous => prev != null,
        DeleteFill.following => next != null,
        DeleteFill.split => prev != null && next != null,
        DeleteFill.leaveEmpty => prev == null && next == null && !e.isOpen,
      };
      if (!ok) throw const EditException('That option is not available.');

      // Delete first: if `e` is open, `prev` may only become open afterwards.
      await entries.delete(e.id);
      final touched = <int>[];
      switch (fill) {
        case DeleteFill.previous:
          await entries.setBounds(prev!.id, prev.start, e.end);
          touched.add(prev.id);
        case DeleteFill.following:
          await entries.setBounds(next!.id, e.start, next.end);
          touched.add(next.id);
        case DeleteFill.split:
          final mid = e.start.add(e.end!.difference(e.start) ~/ 2);
          await entries.setBounds(prev!.id, prev.start, mid);
          await entries.setBounds(next!.id, mid, next.end);
          touched.addAll([prev.id, next.id]);
        case DeleteFill.leaveEmpty:
          break;
      }
      await _splitAll(txn, touched, now);
    });
    await _changed();
  }

  // ---- Split -------------------------------------------------------------

  /// Splits an entry at [at] into two entries of the same activity.
  Future<void> split(int entryId, DateTime at) async {
    await _db.transaction((txn) async {
      final entries = TimeEntryRepository(txn);
      final e = await _entry(txn, entryId);
      final end = e.end ?? _clock.now();
      if (!at.isAfter(e.start) || !at.isBefore(end)) {
        throw const EditException('Choose a time inside the entry.');
      }
      if (e.isOpen) {
        await entries.close(e.id, at);
      } else {
        await entries.setBounds(e.id, e.start, at);
      }
      await entries.insert(activityId: e.activityId, start: at, end: e.end);
    });
    await _changed();
  }

  // ---- Helpers -----------------------------------------------------------

  Future<TimeEntry> _entry(DatabaseExecutor db, int id) async {
    final e = await TimeEntryRepository(db).byId(id);
    if (e == null) throw const EditException('This entry no longer exists.');
    return e;
  }

  Future<void> _applyPlan(Transaction txn, _Plan plan) async {
    final entries = TimeEntryRepository(txn);
    final now = _clock.now();
    for (final id in plan.removals) {
      await entries.delete(id);
    }
    // Closed bounds first, the (single) open entry last, then inserts:
    // keeps the "one open entry" constraint satisfied at every step.
    final updates = [...plan.updates]
      ..sort((a, b) => (a.end == null ? 1 : 0) - (b.end == null ? 1 : 0));
    final touched = <int>[];
    for (final u in updates) {
      if (u.end != null && !u.end!.isAfter(u.start)) {
        await entries.delete(u.id); // nothing left of it
        continue;
      }
      await entries.setBounds(u.id, u.start, u.end);
      touched.add(u.id);
    }
    for (final i in plan.inserts) {
      if (i.end != null && !i.end!.isAfter(i.start)) continue;
      touched.add(
        await entries.insert(
          activityId: i.activityId,
          start: i.start,
          end: i.end,
        ),
      );
    }
    await _splitAll(txn, touched, now);
  }

  Future<void> _splitAll(Transaction txn, List<int> ids, DateTime now) async {
    final entries = TimeEntryRepository(txn);
    for (final id in ids) {
      final e = await entries.byId(id);
      if (e != null) await splitAtLocalMidnights(entries, e, now);
    }
  }

  Future<void> _changed() async {
    notifyListeners();
    await _tracking.reconcile();
  }
}

class _Plan {
  final effects = <EntryEffect>[];
  final updates = <({int id, DateTime start, DateTime? end})>[];
  final removals = <int>[];
  final inserts = <({int activityId, DateTime start, DateTime? end})>[];

  void update(int id, DateTime start, DateTime? end) {
    updates.removeWhere((u) => u.id == id);
    updates.add((id: id, start: start, end: end));
  }

  void remove(int id) {
    updates.removeWhere((u) => u.id == id);
    removals.add(id);
  }

  void insert(int activityId, DateTime start, DateTime? end) =>
      inserts.add((activityId: activityId, start: start, end: end));
}
