/// The single place where instants are converted to and from storage.
///
/// Persisted format: 64-bit integer, microseconds since
/// 1970-01-01T00:00:00Z (UTC). Never a formatted date string. Values read
/// back are UTC `DateTime`s; convert with `toLocal()` only for display or
/// local calendar boundaries.
int toStoredTimestamp(DateTime t) => t.toUtc().microsecondsSinceEpoch;

DateTime fromStoredTimestamp(int value) =>
    DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);

DateTime? fromStoredTimestampOrNull(Object? value) =>
    value == null ? null : fromStoredTimestamp(value as int);
