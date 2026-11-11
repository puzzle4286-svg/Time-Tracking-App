import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/app/settings_controller.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/repositories/settings_repository.dart';

import '../support/test_database.dart';

void main() {
  late Database db;
  late SettingsRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('defaults when nothing is stored', () async {
    final s = await repo.load();
    expect(s.appearance, const AppSettings().appearance);
    expect(s.accent, const AppSettings().accent);
  });

  test('round-trips saved settings', () async {
    await repo.save(
      const AppSettings(
        appearance: AppearanceMode.black,
        accent: AccentPalette.rose,
      ),
    );
    final s = await repo.load();
    expect(s.appearance, AppearanceMode.black);
    expect(s.accent, AccentPalette.rose);
  });

  test('unknown stored values fall back to defaults', () async {
    await db.insert('settings', {'key': 'appearance', 'value': 'sepia'});
    expect((await repo.load()).appearance, const AppSettings().appearance);
  });

  test('controller persists changes and notifies', () async {
    final controller = SettingsController(repo, await repo.load());
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setAppearance(AppearanceMode.light);
    await controller.setAccent(AccentPalette.amber);

    expect(notified, 2);
    final stored = await repo.load();
    expect(stored.appearance, AppearanceMode.light);
    expect(stored.accent, AccentPalette.amber);
  });
}
