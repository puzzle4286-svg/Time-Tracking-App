/// Database schema, expressed as ordered migrations.
///
/// `migrations[n]` upgrades a database from version n-1 to version n. Never
/// edit a migration that has shipped; add a new one instead.
const Map<int, List<String>> migrations = {
  1: [
    '''
    CREATE TABLE activities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      color INTEGER NOT NULL,
      position INTEGER CHECK (position BETWEEN 1 AND 8),
      is_system INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      deleted_at INTEGER
    )
    ''',
    '''
    CREATE UNIQUE INDEX activities_live_position
      ON activities(position)
      WHERE deleted_at IS NULL AND position IS NOT NULL
    ''',
    '''
    CREATE TABLE time_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER NOT NULL
        REFERENCES activities(id) ON DELETE RESTRICT,
      start_utc INTEGER NOT NULL,
      end_utc INTEGER,
      CHECK (end_utc IS NULL OR end_utc >= start_utc)
    )
    ''',
    // At most one open (active) entry can exist.
    '''
    CREATE UNIQUE INDEX time_entries_one_open
      ON time_entries((1))
      WHERE end_utc IS NULL
    ''',
    'CREATE INDEX time_entries_start ON time_entries(start_utc)',
    'CREATE INDEX time_entries_activity ON time_entries(activity_id)',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ],
};

int get schemaVersion => migrations.keys.reduce((a, b) => a > b ? a : b);
