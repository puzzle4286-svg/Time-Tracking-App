import 'package:sqflite/sqflite.dart';

import '../models/time_entry.dart';

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
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch],
      orderBy: 'start_utc, id',
    );
    return rows.map(TimeEntry.fromRow).toList();
  }

  Future<int> insert({
    required int activityId,
    required DateTime start,
    DateTime? end,
  }) {
    return _db.insert('time_entries', {
      'activity_id': activityId,
      'start_utc': start.millisecondsSinceEpoch,
      'end_utc': end?.millisecondsSinceEpoch,
    });
  }

  Future<void> delete(int id) =>
      _db.delete('time_entries', where: 'id = ?', whereArgs: [id]);

  Future<void> close(int id, DateTime end) async {
    final updated = await _db.update(
      'time_entries',
      {'end_utc': end.millisecondsSinceEpoch},
      where: 'id = ? AND end_utc IS NULL',
      whereArgs: [id],
    );
    if (updated != 1) {
      throw StateError('Entry $id is not open and cannot be closed.');
    }
  }
}
