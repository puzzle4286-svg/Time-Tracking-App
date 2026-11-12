// Runs the real app on a device (`flutter test integration_test -d linux`)
// with a database file on disk. Only the system file dialog is replaced:
// files are written to and read from a temporary directory.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/app/app_root.dart';
import 'package:time_tracker/database/app_database.dart';
import 'package:time_tracker/services/export/backup_files.dart';
import 'package:time_tracker/util/clock.dart';

/// Saves into [dir]; "picks" the most recently saved JSON file.
class DirectoryFiles implements BackupFiles {
  DirectoryFiles(this.dir);

  final Directory dir;
  File? lastJson;

  @override
  Future<String?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    if (fileName.endsWith('.json')) lastJson = file;
    return file.path;
  }

  @override
  Future<Uint8List?> pickJson() async => lastJson?.readAsBytes();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('back up, change, restore on the real app', (tester) async {
    final dir = await Directory.systemTemp.createTemp('time_tracker_it');
    addTearDown(() => dir.delete(recursive: true));
    sqfliteFfiInit();
    final db = await openAppDatabase(
      databaseFactoryFfi,
      p.join(dir.path, databaseFileName),
    );
    addTearDown(db.close);
    const clock = SystemClock();
    final files = DirectoryFiles(dir);

    await tester.pumpWidget(
      AppRoot(
        db: db,
        clock: clock,
        services: await AppServices.load(db, clock),
        files: files,
      ),
    );
    await tester.pumpAndSettle();

    // Set up an activity in slot 1 and start it.
    await tester.tap(find.byKey(const Key('activity-tile-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Reading');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsWidgets);

    Future<void> openData() async {
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restore from backup'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }

    await openData();
    await tester.tap(find.text('Export time entries (CSV)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back up all data (JSON)'));
    await tester.pumpAndSettle();

    final saved = dir.listSync().map((e) => p.basename(e.path)).toList();
    expect(saved.where((n) => n.endsWith('.csv')), hasLength(1));
    expect(saved.where((n) => n.endsWith('.json')), hasLength(1));
    final csv = await File(
      p.join(dir.path, saved.firstWhere((n) => n.endsWith('.csv'))),
    ).readAsString();
    expect(csv, contains('\r\nReading,'));

    // Change the data after the backup: rename the activity.
    await db.update('activities', {
      'name': 'Changed',
    }, where: "name = 'Reading'");

    await tester.tap(find.text('Restore from backup'));
    await tester.pumpAndSettle();
    expect(find.text('Replace all data?'), findsOneWidget);
    await tester.tap(find.text('Replace all data'));
    await tester.pumpAndSettle();

    expect(find.text('Backup restored'), findsOneWidget);
    expect(find.text('Reading'), findsWidgets); // back on Track, restored
    final names = (await db.query('activities')).map((r) => r['name']);
    expect(names, contains('Reading'));
    expect(names, isNot(contains('Changed')));
  });
}
