import 'package:sqflite/sqflite.dart';

/// Small persisted UI conveniences (scroll positions), kept in the
/// `settings` table under `ui.`-prefixed keys. Loaded once at startup so
/// screens can read values synchronously; writes go straight to the database.
class UiStateStore {
  UiStateStore._(this._db, this._values);

  static const _prefix = 'ui.';

  final DatabaseExecutor _db;
  final Map<String, String> _values;

  static Future<UiStateStore> load(DatabaseExecutor db) async {
    final rows = await db.query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['$_prefix%'],
    );
    return UiStateStore._(db, {
      for (final r in rows)
        (r['key']! as String).substring(_prefix.length): r['value']! as String,
    });
  }

  String? get(String key) => _values[key];

  double? getDouble(String key) => double.tryParse(_values[key] ?? '');

  Future<void> set(String key, String value) async {
    if (_values[key] == value) return;
    _values[key] = value;
    await _db.insert('settings', {
      'key': '$_prefix$key',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
