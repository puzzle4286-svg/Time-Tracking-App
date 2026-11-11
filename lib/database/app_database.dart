import 'package:sqflite/sqflite.dart';

import 'schema.dart';

const String databaseFileName = 'time_tracker.db';

/// Opens (creating or migrating as needed) the app database.
///
/// [factory] is injectable so tests can use the FFI implementation; tests also
/// pass `singleInstance: false` so each in-memory database is independent.
Future<Database> openAppDatabase(
  DatabaseFactory factory,
  String path, {
  bool singleInstance = true,
}) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      singleInstance: singleInstance,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
      onDowngrade: (db, from, to) => throw StateError(
        'Database version $from is newer than this app supports ($to).',
      ),
    ),
  );
}

Future<void> _migrate(Database db, int from, int to) async {
  // sqflite already runs onCreate/onUpgrade inside a transaction.
  for (var version = from + 1; version <= to; version++) {
    for (final statement in migrations[version]!) {
      await db.execute(statement);
    }
  }
}
