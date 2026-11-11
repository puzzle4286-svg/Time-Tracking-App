/// Live session format: `0:05:09`, `1:42:15`, `27:00:00`.
String formatClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s ~/ 60) % 60;
  final sec = s % 60;
  return '$h:${_two(m)}:${_two(sec)}';
}

/// Total format: `0m`, `42m`, `2h 42m`, `5h 0m`. Seconds are dropped.
String formatTotal(Duration d) {
  final minutes = d.isNegative ? 0 : d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m}m';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Like [formatTotal], but shows seconds for entries under a minute (`45s`),
/// so very short entries do not read as `0m`.
String formatEntryDuration(Duration d) {
  if (d.isNegative) return '0s';
  return d.inMinutes == 0 ? '${d.inSeconds}s' : formatTotal(d);
}

/// Precise format for comparing durations in dialogs, where two values can
/// fall in the same minute: `40s`, `1m 37s`, `2h 5m`.
String formatDurationPrecise(Duration d) {
  if (d.isNegative) return '0s';
  final s = d.inSeconds;
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
  return formatTotal(d);
}
