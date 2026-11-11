import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/database/app_database.dart';

/// Opens the real app schema on an FFI SQLite database (in memory by default).
Future<Database> openTestDatabase([String path = inMemoryDatabasePath]) {
  sqfliteFfiInit();
  return openAppDatabase(
    databaseFactoryFfiNoIsolate,
    path,
    singleInstance: path != inMemoryDatabasePath,
  );
}
