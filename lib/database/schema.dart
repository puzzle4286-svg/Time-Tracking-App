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
  // v2: timestamps change from epoch milliseconds to epoch microseconds
  // (UTC). Column names are kept; their unit is now microseconds.
  2: [
    '''
    UPDATE time_entries
      SET start_utc = start_utc * 1000,
          end_utc = CASE WHEN end_utc IS NULL THEN NULL ELSE end_utc * 1000 END
    ''',
    '''
    UPDATE activities
      SET created_at = created_at * 1000,
          deleted_at = CASE WHEN deleted_at IS NULL THEN NULL
                            ELSE deleted_at * 1000 END
    ''',
  ],
  // v3: built-in "Default" activity. `role` marks system activities
  // ('default', 'unavailable'). Existing installs get a Default row; fresh
  // installs get it from seeding (the table is still empty here then).
  3: [
    'ALTER TABLE activities ADD COLUMN role TEXT',
    "UPDATE activities SET role = 'unavailable' WHERE is_system = 1",
    '''
    INSERT INTO activities (name, color, position, is_system, role, created_at)
      SELECT 'Default', 4287669422, NULL, 1, 'default',
             CAST(strftime('%s', 'now') AS INTEGER) * 1000000
      WHERE EXISTS (SELECT 1 FROM activities)
        AND NOT EXISTS (SELECT 1 FROM activities WHERE role = 'default')
    ''',
    '''
    CREATE UNIQUE INDEX activities_one_per_role
      ON activities(role) WHERE role IS NOT NULL
    ''',
  ],
  // v4: goals. The period start is a local calendar rule stored as fields
  // (not an instant); targets are durations in microseconds.
  4: [
    '''
    CREATE TABLE goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER NOT NULL
        REFERENCES activities(id) ON DELETE RESTRICT,
      name TEXT,
      period_unit TEXT NOT NULL
        CHECK (period_unit IN ('hour', 'day', 'week', 'month')),
      period_length INTEGER NOT NULL CHECK (period_length >= 1),
      anchor_year INTEGER NOT NULL,
      anchor_month INTEGER NOT NULL CHECK (anchor_month BETWEEN 1 AND 12),
      anchor_day INTEGER NOT NULL CHECK (anchor_day BETWEEN 1 AND 31),
      anchor_minute INTEGER NOT NULL CHECK (anchor_minute BETWEEN 0 AND 1439),
      min_us INTEGER CHECK (min_us IS NULL OR min_us > 0),
      max_us INTEGER CHECK (max_us IS NULL OR max_us > 0),
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      CHECK (min_us IS NOT NULL OR max_us IS NOT NULL),
      CHECK (min_us IS NULL OR max_us IS NULL OR min_us <= max_us)
    )
    ''',
    'CREATE INDEX goals_activity ON goals(activity_id)',
  ],
  // v5: optional tile icon, a key from `activityIcons` (null = none).
  5: ['ALTER TABLE activities ADD COLUMN icon TEXT'],
};

int get schemaVersion => migrations.keys.reduce((a, b) => a > b ? a : b);
