import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/app_root.dart';
import 'package:time_tracker/services/export/backup_files.dart';
import 'package:time_tracker/services/export/backup_service.dart';

import '../support/tracking_fixture.dart';

class FakeFiles implements BackupFiles {
  final saved = <String, Uint8List>{};
  Uint8List? toPick;

  @override
  Future<String?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved[fileName] = bytes;
    return '/backups/$fileName';
  }

  @override
  Future<Uint8List?> pickJson() async => toPick;
}

void main() {
  final monday9 = DateTime(2026, 11, 9, 9);
  late TrackingFixture f;
  late FakeFiles files;

  setUp(() async {
    f = await TrackingFixture.create(monday9);
    files = FakeFiles();
  });
  tearDown(() => f.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      AppRoot(
        db: f.db,
        clock: f.clock,
        services: await AppServices.load(f.db, f.clock),
        files: files,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Restore from backup'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    // Fully into view: just "visible" can leave it under the navigation bar.
    await tester.ensureVisible(find.text('Restore from backup'));
    await tester.pumpAndSettle();
  }

  String currentActivity(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('current-activity-name'))).data!;

  testWidgets('CSV export and backup are saved through the file dialog', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Export time entries (CSV)'));
    await settle(tester);
    final csvName = files.saved.keys.single;
    expect(csvName, endsWith('.csv'));
    expect(
      utf8.decode(files.saved[csvName]!),
      startsWith(
        'activity,start,end,start_utc_us,end_utc_us,duration_us\r\n'
        'Free Time,',
      ),
    );
    expect(
      find.textContaining('CSV export saved to /backups/'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back up all data (JSON)'));
    await settle(tester);
    final jsonName = files.saved.keys.firstWhere((k) => k.endsWith('.json'));
    final json = jsonDecode(utf8.decode(files.saved[jsonName]!)) as Map;
    expect(json['format'], 'time-tracker-backup');
  });

  testWidgets('restore asks first; cancel keeps the current data', (
    tester,
  ) async {
    files.toPick = (await BackupService(f.db, f.clock).createBackup()).encode();
    await f.service.switchTo(f.gaming);
    await openSettings(tester);

    await tester.tap(find.text('Restore from backup'));
    await settle(tester);
    expect(find.text('Replace all data?'), findsOneWidget);
    final summary = tester
        .widget<Text>(find.byKey(const Key('restore-summary')))
        .data!;
    expect(summary, contains('3 activities, 1 time entry, 0 goals'));
    expect(summary, contains('cannot be undone'));

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Replace all data?'), findsNothing);
    expect(f.service.current.activity.id, f.gaming);
  });

  testWidgets('restore replaces the data and reloads the app', (tester) async {
    files.toPick = (await BackupService(f.db, f.clock).createBackup()).encode();
    f.clock.advance(const Duration(minutes: 10));
    await f.service.switchTo(f.gaming);
    await f.db.update('activities', {
      'name': 'Renamed',
    }, where: 'id = ${f.study}');
    await openSettings(tester);

    await tester.tap(find.text('Restore from backup'));
    await settle(tester);
    await tester.tap(find.text('Replace all data'));
    await settle(tester);

    // Fresh app on the Track tab, running the restored activity.
    expect(find.text('Backup restored'), findsOneWidget);
    expect(currentActivity(tester), 'Free Time');
    final names = await f.db.query('activities', columns: ['name']);
    expect(names.map((r) => r['name']), contains('Study'));
    expect(names.map((r) => r['name']), isNot(contains('Renamed')));
    expect(await f.entries(), hasLength(1));
  });

  testWidgets('an invalid file is explained and changes nothing', (
    tester,
  ) async {
    files.toPick = Uint8List.fromList(utf8.encode('{"format": "other"}'));
    await openSettings(tester);
    await tester.tap(find.text('Restore from backup'));
    await settle(tester);
    expect(find.text('Cannot restore this file'), findsOneWidget);
    expect(find.textContaining('not a Lifestring backup'), findsOneWidget);
    expect(find.textContaining('was not changed'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(await f.entries(), hasLength(1));
  });
}
