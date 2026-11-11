/// A half-open time range `[start, end)`.
class TimeRange {
  TimeRange(this.start, this.end) {
    if (end.isBefore(start)) {
      throw ArgumentError('Range end $end is before start $start.');
    }
  }

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// How much of `[otherStart, otherEnd)` lies inside this range.
  Duration overlap(DateTime otherStart, DateTime otherEnd) {
    final from = otherStart.isAfter(start) ? otherStart : start;
    final to = otherEnd.isBefore(end) ? otherEnd : end;
    return to.isAfter(from) ? to.difference(from) : Duration.zero;
  }

  @override
  String toString() => 'TimeRange($start – $end)';
}

/// Local midnight at the start of the calendar day containing [t].
///
/// Built from calendar fields, so it is correct on days that are 23 or 25
/// hours long. If midnight does not exist (DST jump at 00:00), Dart resolves
/// it to the first valid local time of that day.
DateTime startOfLocalDay(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The first local midnight strictly after [t].
DateTime nextLocalMidnight(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

/// The local calendar day containing [t].
TimeRange localDay(DateTime t) =>
    TimeRange(startOfLocalDay(t), nextLocalMidnight(t));
