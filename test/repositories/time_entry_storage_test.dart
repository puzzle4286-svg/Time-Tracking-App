import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/seed.dart';
import 'package:time_tracker/repositories/time_entry_repository.dart';

import '../support/test_database.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDatabase();
  });
  tearDown(() => db.close());

  test('stores UTC epoch microseconds and reads back UTC', () async {
    // A local time with sub-millisecond precision.
    final local = DateTime(2026, 11, 9, 23, 59, 59, 123, 456);
    await ensureSeeded(db, local);

    final raw = (await db.query('time_entries')).single['start_utc'];
    expect(raw, local.toUtc().microsecondsSinceEpoch);
    expect(raw, isA<int>());

    final entry = (await TimeEntryRepository(db).openEntry())!;
    expect(entry.start.isUtc, isTrue);
    expect(entry.start, local.toUtc());
    expect(entry.start.microsecond, 456);
  });
}
