/// Source of the current time. All time-dependent logic takes a [Clock] so
/// tests can control time instead of relying on the real system clock.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
