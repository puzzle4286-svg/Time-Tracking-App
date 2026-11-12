import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import '../tracking/entry_normalization.dart';
import '../tracking/tracking_service.dart';

/// An edit that cannot be applied, with a message for the user.
class EditException implements Exception {
  const EditException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum EffectKind { shortened, extended, removed, splitAround, added }

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

  /// The time goes to a chosen activity (the entry's activity changes).
  /// Offered when no neighbour is adjacent; time is never left empty.
  activity,
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

enum FreedSide { start, end }

/// Time an edit takes away from the edited entry (old range minus new), and
/// the adjacent entry on that side. [neighbour] is null if nothing touches
/// that side, or if it is the same activity as the edited entry (filling with
/// it would undo the edit, e.g. around midnight).
class FreedRange {
  const FreedRange({
    required this.side,
    required this.start,
    required this.end,
    required this.neighbour,
  });

  final FreedSide side;
  final DateTime start;
  final DateTime end;
  final Activity? neighbour;

  Duration get duration => end.difference(start);
}

/// Edits of historical time entries. Every edit is one transaction; entries
/// are re-split at local midnights and same-activity neighbours merged
/// afterwards (an activity only follows itself at midnight), and tracking is
/// reconciled so the current session and all statistics follow.
class EntryEditService extends ChangeNotifier {
  EntryEditService(this._db, this._clock, this._tracking);

  final Database _db;
  final Clock _clock;
  final TrackingService _tracking;

  // ---- Change activity ----------------------------------------------------

  Future<void> changeActivity(int entryId, int activityId) async {
    await _db.transaction((txn) async {
      await _checkAssignable(txn, activityId);
      final e = await _entry(txn, entryId);
      final entries = TimeEntryRepository(txn);
      await entries.setActivity(entryId, activityId);
      await _mergeAround(entries, e.start, e.end ?? _clock.now());
    });
    await _changed();
  }

  // ---- Change start / end ---------------------------------------------------

  /// Changes an entry's bounds. With [apply] false nothing is written and
  /// the effects on other entries are returned for confirmation; with
  /// [apply] true the same plan is recomputed and applied atomically.
  ///
  /// Rules: overlapped entries are shortened, split around the edited entry,
  /// or removed if fully covered. Time the edited entry gives up (see
  /// [freedRanges]) always goes to an activity: the one chosen in [fills],
  /// otherwise the adjacent neighbour, otherwise Default. Time is never left
  /// empty. The end of the running entry cannot be set.
  Future<List<EntryEffect>> retime(
    int entryId, {
    required DateTime start,
    DateTime? end,
    Map<FreedSide, int> fills = const {},
    required bool apply,
  }) async {
    final effects = await _db.transaction((txn) async {
      final old = await _entry(txn, entryId);
      final plan = await _planRetime(txn, entryId, start, end, fills);
      if (apply) {
        await _applyPlan(txn, plan);
        final now = _clock.now();
        final from = start.isBefore(old.start) ? start : old.start;
        final oldEnd = old.end ?? now;
        final newEnd = end ?? now;
        await _mergeAround(
          TimeEntryRepository(txn),
          from,
          newEnd.isAfter(oldEnd) ? newEnd : oldEnd,
        );
      }
      return plan.effects;
    });
    if (apply) await _changed();
    return effects;
  }

  /// The parts of [entryId]'s current range that the new bounds give up.
  Future<List<FreedRange>> freedRanges(
    int entryId, {
    required DateTime start,
    DateTime? end,
  }) => _db.transaction((txn) async {
    final e = await _entry(txn, entryId);
    final activities = await ActivityRepository(txn).allById();
    return [
      for (final f in await _freed(
        txn,
        e,
        start,
        e.isOpen ? null : end ?? e.end,
      ))
        FreedRange(
          side: f.side,
          start: f.start,
          end: f.end,
          neighbour:
              f.neighbour == null || f.neighbour!.activityId == e.activityId
              ? null
              : activities[f.neighbour!.activityId],
        ),
    ];
  });

  /// Old range minus new range, per side, with the adjacent entry there.
  Future<
    List<({FreedSide side, DateTime start, DateTime end, TimeEntry? neighbour})>
  >
  _freed(Transaction txn, TimeEntry e, DateTime start, DateTime? end) async {
    final entries = TimeEntryRepository(txn);
    final now = _clock.now();
    final oldEnd = e.end ?? now;
    return [
      if (start.isAfter(e.start))
        (
          side: FreedSide.start,
          start: e.start,
          end: start.isBefore(oldEnd) ? start : oldEnd,
          neighbour: await entries.endingAt(e.start, excludeId: e.id),
        ),
      if (end != null && end.isBefore(oldEnd))
        (
          side: FreedSide.end,
          start: end.isAfter(e.start) ? end : e.start,
          end: oldEnd,
          neighbour: e.isOpen
              ? null
              : await entries.startingAt(oldEnd, excludeId: e.id),
        ),
    ];
  }

  Future<_Plan> _planRetime(
    Transaction txn,
    int entryId,
    DateTime start,
    DateTime? requestedEnd,
    Map<FreedSide, int> fills,
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

    // Shrinking: fill the freed time as chosen. Filling with the adjacent
    // neighbour's activity extends that neighbour.
    final defaultId = (await ActivityRepository(
      txn,
    ).withRole(SystemRole.defaultActivity))!.id;
    for (final f in await _freed(txn, e, start, end)) {
      final neighbour = f.neighbour;
      final fillId =
          fills[f.side] ??
          (neighbour != null && neighbour.activityId != e.activityId
              ? neighbour.activityId
              : defaultId);
      await _checkAssignable(txn, fillId, notSameAs: e.activityId);
      final fill = activities[fillId]!;
      if (neighbour != null && neighbour.activityId == fillId) {
        final (s, t) = f.side == FreedSide.start
            ? (neighbour.start, f.end)
            : (f.start, neighbour.end);
        plan.update(neighbour.id, s, t);
        plan.effects.add(effect(EffectKind.extended, neighbour, s, t));
      } else {
        plan.insert(fillId, f.start, f.end);
        plan.effects.add(
          EntryEffect(
            kind: EffectKind.added,
            entry: TimeEntry(
              id: -1,
              activityId: fillId,
              start: f.start,
              end: f.end,
            ),
            activity: fill,
            newStart: f.start,
            newEnd: f.end,
          ),
        );
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
        // Same activity on both sides: every fill gives the same merged
        // result, so offer just one.
        if (next != null && next.activityId != prev?.activityId)
          DeleteFill.following,
        if (prev != null && next != null && prev.activityId != next.activityId)
          DeleteFill.split,
        // Nothing adjacent: the time goes to an activity the user picks.
        if (prev == null && next == null) DeleteFill.activity,
      ],
    );
  }

  /// Deletes an entry and fills its time as chosen. Deleting the running
  /// entry with [DeleteFill.previous] resumes the previous activity. With
  /// [DeleteFill.activity], [activityId] takes over the time.
  Future<void> delete(int entryId, DeleteFill fill, {int? activityId}) async {
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
        DeleteFill.activity => prev == null && next == null,
      };
      if (!ok) throw const EditException('That option is not available.');

      if (fill == DeleteFill.activity) {
        await _checkAssignable(txn, activityId, notSameAs: e.activityId);
        await entries.setActivity(e.id, activityId!);
        await _mergeAround(entries, e.start, e.end ?? now);
        return;
      }

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
        case DeleteFill.activity:
          break; // handled above
      }
      await _splitAll(txn, touched, now);
      await _mergeAround(entries, e.start, e.end ?? now);
    });
    await _changed();
  }

  // ---- Helpers -----------------------------------------------------------

  /// Throws unless [activityId] may take time (a grid activity or Default)
  /// and differs from [notSameAs].
  Future<void> _checkAssignable(
    DatabaseExecutor db,
    int? activityId, {
    int? notSameAs,
  }) async {
    final a = activityId == null
        ? null
        : await ActivityRepository(db).byId(activityId);
    if (a == null || !a.canTakeTime) {
      throw const EditException('Choose one of your activities or Default.');
    }
    if (a.id == notSameAs) {
      throw const EditException('Choose a different activity.');
    }
  }

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

  /// Merges same-activity neighbours a day either side of [from]–[to].
  Future<void> _mergeAround(
    TimeEntryRepository entries,
    DateTime from,
    DateTime to,
  ) => mergeSameActivityNeighbours(
    entries,
    from.subtract(const Duration(days: 1)),
    to.add(const Duration(days: 1)),
  );

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
