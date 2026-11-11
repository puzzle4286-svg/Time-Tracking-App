import 'package:sqflite/sqflite.dart';

import '../models/time_entry.dart';
import '../util/timestamps.dart';

/// SQL access for the `time_entries` table.
class TimeEntryRepository {
  const TimeEntryRepository(this._db);

  final DatabaseExecutor _db;

  /// The active session, or null if (incorrectly) none exists.
  Future<TimeEntry?> openEntry() async {
    final rows = await _db.query('time_entries', where: 'end_utc IS NULL');
    return rows.isEmpty ? null : TimeEntry.fromRow(rows.single);
  }

  Future<TimeEntry?> byId(int id) async {
    final rows = await _db.query(
      'time_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : TimeEntry.fromRow(rows.single);
  }

  /// The entry (other than [excludeId]) whose end is exactly [t].
  Future<TimeEntry?> endingAt(DateTime t, {int? excludeId}) =>
      _single('end_utc = ?', [toStoredTimestamp(t)], excludeId);

  /// The entry (other than [excludeId]) whose start is exactly [t].
  Future<TimeEntry?> startingAt(DateTime t, {int? excludeId}) =>
      _single('start_utc = ?', [toStoredTimestamp(t)], excludeId);

  Future<TimeEntry?> _single(
    String where,
    List<Object?> args,
    int? excludeId,
  ) async {
    final rows = await _db.query(
      'time_entries',
      where: excludeId == null ? where : '$where AND id != ?',
      whereArgs: excludeId == null ? args : [...args, excludeId],
      orderBy: 'id',
      limit: 1,
    );
    return rows.isEmpty ? null : TimeEntry.fromRow(rows.single);
  }

  Future<int> countForActivity(int activityId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM time_entries WHERE activity_id = ?',
      [activityId],
    );
    return rows.single['n']! as int;
  }

  /// Entries that overlap the half-open range [from, to), oldest first.
  /// Open entries count as extending indefinitely.
  Future<List<TimeEntry>> overlapping(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'time_entries',
      where: 'start_utc < ? AND (end_utc IS NULL OR end_utc > ?)',
      whereArgs: [toStoredTimestamp(to), toStoredTimestamp(from)],
      orderBy: 'start_utc, id',
    );
    return rows.map(TimeEntry.fromRow).toList();
  }

  /// Start of the oldest entry, or null if there are none.
  Future<DateTime?> earliestStart() async {
    final rows = await _db.rawQuery(
      'SELECT MIN(start_utc) AS s FROM time_entries',
    );
    return fromStoredTimestampOrNull(rows.single['s']);
  }

  Future<int> insert({
    required int activityId,
    required DateTime start,
    DateTime? end,
  }) {
    return _db.insert('time_entries', {
      'activity_id': activityId,
      'start_utc': toStoredTimestamp(start),
      'end_utc': end == null ? null : toStoredTimestamp(end),
    });
  }

  /// Sets both bounds of an entry. [end] null makes it the open entry, so
  /// no other entry may be open at that moment.
  Future<void> setBounds(int id, DateTime start, DateTime? end) async {
    final updated = await _db.update(
      'time_entries',
      {
        'start_utc': toStoredTimestamp(start),
        'end_utc': end == null ? null : toStoredTimestamp(end),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Entry $id does not exist.');
  }

  Future<void> setActivity(int id, int activityId) => _db.update(
    'time_entries',
    {'activity_id': activityId},
    where: 'id = ?',
    whereArgs: [id],
  );

  /// Moves every entry of [from] to [to]; returns how many moved.
  Future<int> reassignActivity(int from, int to) => _db.update(
    'time_entries',
    {'activity_id': to},
    where: 'activity_id = ?',
    whereArgs: [from],
  );

  Future<void> delete(int id) =>
      _db.delete('time_entries', where: 'id = ?', whereArgs: [id]);

  Future<void> close(int id, DateTime end) async {
    final updated = await _db.update(
      'time_entries',
      {'end_utc': toStoredTimestamp(end)},
      where: 'id = ? AND end_utc IS NULL',
      whereArgs: [id],
    );
    if (updated != 1) {
      throw StateError('Entry $id is not open and cannot be closed.');
    }
  }
}
