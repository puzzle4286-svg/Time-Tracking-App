import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';

/// Persists [AppSettings] as key/value rows in the `settings` table.
class SettingsRepository {
  const SettingsRepository(this._db);

  final DatabaseExecutor _db;

  static const _appearanceKey = 'appearance';
  static const _accentKey = 'accent';
  static const _neonKey = 'neon';

  /// Loads settings; missing or unknown values fall back to defaults.
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    const defaults = AppSettings();
    return AppSettings(
      appearance: _byName(
        AppearanceMode.values,
        values[_appearanceKey],
        defaults.appearance,
      ),
      accent: _byName(
        AccentPalette.values,
        values[_accentKey],
        defaults.accent,
      ),
      neon: switch (values[_neonKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.neon,
      },
    );
  }

  Future<void> save(AppSettings settings) async {
    final batch = _db.batch();
    for (final MapEntry(:key, :value) in {
      _appearanceKey: settings.appearance.name,
      _accentKey: settings.accent.name,
      _neonKey: settings.neon.toString(),
    }.entries) {
      batch.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;
