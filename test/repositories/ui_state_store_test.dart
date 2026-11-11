import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/repositories/ui_state_store.dart';

import '../support/test_database.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('values persist and are reloaded', () async {
    final store = await UiStateStore.load(db);
    expect(store.get('a'), isNull);
    await store.set('a', 'x');
    await store.set('scroll', '123.5');

    final reloaded = await UiStateStore.load(db);
    expect(reloaded.get('a'), 'x');
    expect(reloaded.getDouble('scroll'), 123.5);
  });

  test('does not interfere with app settings', () async {
    final settings = SettingsRepository(db);
    await settings.save(const AppSettings(appearance: AppearanceMode.black));
    final store = await UiStateStore.load(db);
    await store.set('appearance', 'light'); // stored as ui.appearance

    expect((await settings.load()).appearance, AppearanceMode.black);
    expect((await UiStateStore.load(db)).get('appearance'), 'light');
  });
}
