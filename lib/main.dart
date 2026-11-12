import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'app/app_root.dart';
import 'database/app_database.dart';
import 'services/widget/switcher_widget.dart';
import 'util/clock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const clock = SystemClock();

  final (factory, dir) = await _databaseLocation();
  final db = await openAppDatabase(factory, p.join(dir, databaseFileName));
  if (Platform.isAndroid) await SwitcherWidget.register();
  runApp(
    AppRoot(
      db: db,
      clock: clock,
      services: await AppServices.load(db, clock),
      syncWidget: Platform.isAndroid,
    ),
  );
}

/// Android uses sqflite's platform plugin. The Linux desktop build (used for
/// development) uses the FFI implementation and stores data under
/// `$XDG_DATA_HOME/time_tracker` (default `~/.local/share/time_tracker`).
Future<(DatabaseFactory, String)> _databaseLocation() async {
  if (!Platform.isLinux) return (databaseFactory, await getDatabasesPath());
  ffi.sqfliteFfiInit();
  final env = Platform.environment;
  final base = env['XDG_DATA_HOME'] ?? p.join(env['HOME']!, '.local', 'share');
  final dir = p.join(base, 'time_tracker');
  await Directory(dir).create(recursive: true);
  return (ffi.databaseFactoryFfi, dir);
}
