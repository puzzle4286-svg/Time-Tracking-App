const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Local 24-hour clock time, e.g. `09:05`.
String formatTimeOfDay(DateTime t) {
  final local = t.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// `Today`, `Yesterday`, or e.g. `Mon, 9 Nov 2026` for the local [day].
String formatDayLabel(DateTime day, DateTime now) {
  final d = day.toLocal();
  final n = now.toLocal();
  final date = DateTime(d.year, d.month, d.day);
  final today = DateTime(n.year, n.month, n.day);
  if (date == today) return 'Today';
  if (date == DateTime(n.year, n.month, n.day - 1)) return 'Yesterday';
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} '
      '${d.year}';
}

/// Short local date, e.g. `Mon 9 Nov`.
String formatShortDate(DateTime t) {
  final d = t.toLocal();
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// Short local date and time, e.g. `Mon 9 Nov, 09:05`.
String formatMoment(DateTime t) =>
    '${formatShortDate(t)}, ${formatTimeOfDay(t)}';

String _two(int n) => n.toString().padLeft(2, '0');
