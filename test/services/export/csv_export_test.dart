import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/export/csv_export.dart';

void main() {
  group('formatLocalIsoWithOffset', () {
    test('round-trips to the same instant (seconds precision)', () {
      // Includes both sides of the Berlin / New York DST changes; whatever
      // the test timezone, the offset written must be the one in effect.
      final instants = [
        DateTime.utc(2026, 1, 15, 12),
        DateTime.utc(2026, 3, 29, 0, 59, 59),
        DateTime.utc(2026, 3, 29, 1, 0, 0),
        DateTime.utc(2026, 7, 1, 23, 30, 15),
        DateTime.utc(2026, 10, 25, 0, 59, 59),
        DateTime.utc(2026, 10, 25, 1, 0, 1),
        DateTime.utc(2026, 11, 1, 6, 30),
      ];
      for (final t in instants) {
        final s = formatLocalIsoWithOffset(t);
        expect(
          s,
          matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$')),
        );
        expect(DateTime.parse(s), t, reason: s);
      }
    });

    test('shows the local wall-clock time', () {
      final local = DateTime(2026, 11, 12, 9, 5, 7, 999);
      expect(
        formatLocalIsoWithOffset(local),
        startsWith('2026-11-12T09:05:07'),
      );
    });
  });

  group('buildEntriesCsv', () {
    final start = DateTime.utc(2026, 11, 12, 8);
    final now = start.add(const Duration(hours: 3));

    test('header, CRLF lines, exact UTC microsecond columns', () {
      final csv = buildEntriesCsv([
        CsvEntry(
          activity: 'Gaming',
          start: start,
          end: start.add(const Duration(minutes: 90, microseconds: 1234567)),
        ),
      ], now);
      final lines = csv.split('\r\n');
      expect(lines, hasLength(3));
      expect(
        lines.first,
        'activity,start,end,start_utc_us,end_utc_us,duration_us',
      );
      expect(lines.last, isEmpty);
      final fields = lines[1].split(',');
      expect(fields[0], 'Gaming');
      expect(DateTime.parse(fields[1]), start);
      expect(fields[3], '${start.microsecondsSinceEpoch}');
      expect(int.parse(fields[4]) - int.parse(fields[3]), 5401234567);
      expect(fields[5], '5401234567');
    });

    test('running entry: empty end, duration up to now', () {
      final csv = buildEntriesCsv([
        CsvEntry(activity: 'Default', start: start),
      ], now);
      final fields = csv.split('\r\n')[1].split(',');
      expect(fields[2], isEmpty);
      expect(fields[4], isEmpty);
      expect(fields[5], '10800000000');
    });

    test('quotes names with commas, quotes and line breaks', () {
      final csv = buildEntriesCsv([
        for (final name in ['a,b', 'say "hi"', 'two\nlines', 'Ünïcode'])
          CsvEntry(activity: name, start: start, end: start),
      ], now);
      expect(csv, contains('\r\n"a,b",'));
      expect(csv, contains('\r\n"say ""hi""",'));
      expect(csv, contains('\r\n"two\nlines",'));
      expect(csv, contains('\r\nÜnïcode,'));
    });

    test('no entries: header only', () {
      expect(
        buildEntriesCsv([], now),
        'activity,start,end,start_utc_us,end_utc_us,duration_us\r\n',
      );
    });
  });
}
