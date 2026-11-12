/// One time entry as it appears in the CSV export.
class CsvEntry {
  const CsvEntry({required this.activity, required this.start, this.end});

  final String activity;
  final DateTime start;

  /// `null` for the running entry.
  final DateTime? end;
}

const csvHeader = [
  'activity',
  'start',
  'end',
  'start_utc_us',
  'end_utc_us',
  'duration_us',
];

/// Builds the time-entry CSV (RFC 4180: comma separated, CRLF line ends,
/// fields quoted when needed).
///
/// `start` / `end` are readable local ISO 8601 times with their UTC offset
/// (`2026-11-12T09:30:00+01:00`, seconds). `start_utc_us` / `end_utc_us` are
/// the exact stored instants (microseconds since 1970-01-01 UTC) and
/// `duration_us` the exact length in microseconds, so the exact columns add
/// up without rounding. The running entry has empty `end` / `end_utc_us`;
/// its duration runs up to [now].
String buildEntriesCsv(List<CsvEntry> entries, DateTime now) {
  final out = StringBuffer()..write(_row(csvHeader));
  for (final e in entries) {
    final end = e.end;
    final us = (end ?? now).difference(e.start).inMicroseconds;
    out.write(
      _row([
        e.activity,
        formatLocalIsoWithOffset(e.start),
        end == null ? '' : formatLocalIsoWithOffset(end),
        '${e.start.microsecondsSinceEpoch}',
        end == null ? '' : '${end.microsecondsSinceEpoch}',
        '${us < 0 ? 0 : us}',
      ]),
    );
  }
  return out.toString();
}

String _row(List<String> fields) => '${fields.map(_escape).join(',')}\r\n';

String _escape(String field) {
  if (!field.contains(RegExp('[",\r\n]'))) return field;
  return '"${field.replaceAll('"', '""')}"';
}

/// `t` in the device's timezone as `yyyy-MM-ddTHH:mm:ss±HH:MM` (seconds
/// truncated).
String formatLocalIsoWithOffset(DateTime t) {
  final local = t.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${_pad(local.year, 4)}-${_pad(local.month)}-${_pad(local.day)}'
      'T${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)}'
      '$sign${_pad(minutes ~/ 60)}:${_pad(minutes % 60)}';
}

String _pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
