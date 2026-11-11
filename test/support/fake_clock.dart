import 'package:time_tracker/util/clock.dart';

/// A clock that only moves when the test tells it to.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime time) => _now = time;

  void advance(Duration duration) => _now = _now.add(duration);
}
