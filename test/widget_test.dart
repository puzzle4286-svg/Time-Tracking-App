import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/app/app.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/repositories/settings_repository.dart';

import 'support/test_database.dart';

void main() {
  late Database db;

  setUpAll(() async => db = await openTestDatabase());
  tearDownAll(() => db.close());

  testWidgets('applies the persisted appearance', (tester) async {
    final settings = SettingsController(
      SettingsRepository(db),
      const AppSettings(appearance: AppearanceMode.black),
    );
    await tester.pumpWidget(
      TimeTrackerApp(settings: settings, home: const Scaffold()),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final context = tester.element(find.byWidget(scaffold));
    expect(Theme.of(context).scaffoldBackgroundColor, Colors.black);
  });
}
