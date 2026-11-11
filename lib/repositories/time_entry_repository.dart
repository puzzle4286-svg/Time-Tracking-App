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
