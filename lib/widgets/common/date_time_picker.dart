import 'package:flutter/material.dart';

/// Picks a local date and time (minute precision). If the user keeps the
/// same minute, [initial] is returned unchanged so its seconds are kept.
Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime initial, {
  required DateTime first,
  required DateTime last,
}) async {
  // The date picker reads calendar fields directly, so every bound must be
  // local: a UTC `now` just after local midnight still has yesterday's date
  // (this made entries around midnight impossible to edit).
  final local = initial.toLocal();
  final firstLocal = first.toLocal();
  final lastLocal = last.toLocal();
  final date = await showDatePicker(
    context: context,
    initialDate: local,
    firstDate: firstLocal.isBefore(local) ? firstLocal : local,
    lastDate: lastLocal.isAfter(local) ? lastLocal : local,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  if (time == null) return null;
  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  final sameMinute =
      picked ==
      DateTime(local.year, local.month, local.day, local.hour, local.minute);
  return sameMinute ? initial : picked;
}
