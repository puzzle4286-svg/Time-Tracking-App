// Runs the real app on the Linux desktop (`flutter test
// integration_test/insights_swipe_test.dart -d linux`) with a database file
// on disk: swiping changes the Insights period without resetting the
// scroll position.
import 'dart:io';

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

  testWidgets('swipe through Insights periods on the real app', (tester) async {
    // Phone-sized window, so the results scroll.
    await binding.setSurfaceSize(const Size(400, 720));
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
    for (var i = 1; i <= 4; i++) {
      final a = await services.activities.create(
        position: i,
        name: 'Activity $i',
        color: 0xFF4CAF50 + i * 0x101010,
      );
      await services.tracking.switchTo(a.id);
    }

    await tester.pumpWidget(
      AppRoot(db: db, clock: clock, services: services, files: _NoFiles()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    String label() =>
        tester.widget<Text>(find.byKey(const Key('insights-period'))).data!;
    final list = find
        .descendant(
          of: find.byKey(const Key('insights-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    double offset() => tester.state<ScrollableState>(list).position.pixels;
    Future<void> swipe(double dx) async {
      await tester.fling(list, Offset(dx, 0), 1000);
      await tester.pumpAndSettle();
    }

    expect(label(), 'Today');
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
    final scrolled = offset();
    expect(scrolled, greaterThan(0));

    await swipe(300);
    expect(label(), 'Yesterday');
    expect(offset(), scrolled);
    await swipe(-300);
    expect(label(), 'Today');
    expect(offset(), scrolled);
    await swipe(-300); // nothing after today
    expect(label(), 'Today');
  });
}
