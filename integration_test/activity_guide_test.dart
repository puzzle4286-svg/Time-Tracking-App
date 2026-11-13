// Runs the real app on the Linux desktop (`flutter test
// integration_test/activity_guide_test.dart -d linux`) with a database file
// on disk: swiping up on the grid opens "Which activity?" and swiping down
// on its list closes it, by touch and by mouse.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/app/app_root.dart';
import 'package:time_tracker/database/app_database.dart';
import 'package:time_tracker/services/export/backup_files.dart';
import 'package:time_tracker/util/clock.dart';

class _NoFiles implements BackupFiles {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"Which activity?" opens with a swipe up, closes with a swipe '
      'down on the list', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => binding.setSurfaceSize(null));
    final dir = await Directory.systemTemp.createTemp('lifestring_it');
    addTearDown(() => dir.delete(recursive: true));
    sqfliteFfiInit();
    final db = await openAppDatabase(
      databaseFactoryFfi,
      p.join(dir.path, databaseFileName),
    );
    addTearDown(db.close);
    const clock = SystemClock();
    final services = await AppServices.load(db, clock);
    final first = await services.activities.create(
      position: 1,
      name: 'Study',
      color: 0xFF4CAF50,
      description: 'Lectures, homework, exam prep',
    );
    await services.activities.create(
      position: 2,
      name: 'Gaming',
      color: 0xFF2196F3,
    );
    await services.tracking.switchTo(first.id);

    await tester.pumpWidget(
      AppRoot(db: db, clock: clock, services: services, files: _NoFiles()),
    );
    await tester.pumpAndSettle();

    final grid = find.byKey(const Key('activity-grid'));
    final title = find.text('Which activity?');
    final list = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    );

    Future<void> open() async {
      await tester.fling(grid, const Offset(0, -120), 800);
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      expect(find.text('Lectures, homework, exam prep'), findsOneWidget);
    }

    // Finger.
    await open();
    await tester.drag(list, const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget, reason: 'a small drag keeps it open');
    await tester.drag(list, const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(title, findsNothing);

    // Mouse (the Linux build is used with one).
    await open();
    await tester.drag(
      list,
      const Offset(0, 150),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(title, findsNothing);

    // Closing switches nothing.
    expect(services.tracking.current.activity.id, first.id);
  });
}
