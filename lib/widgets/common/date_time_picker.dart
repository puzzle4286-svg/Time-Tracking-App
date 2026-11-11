import 'package:flutter/material.dart';

/// Picks a local date and time (minute precision). If the user keeps the
/// same minute, [initial] is returned unchanged so its seconds are kept.
Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime initial, {
  required DateTime first,
  required DateTime last,
}) async {
  final local = initial.toLocal();
  final date = await showDatePicker(
    context: context,
    initialDate: local,
    firstDate: first.isBefore(local) ? first : local,
    lastDate: last.isAfter(local) ? last : local,
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
