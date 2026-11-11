import 'package:flutter_test/flutter_test.dart';

/// Matches a `DateTime` at the same instant as [expected], regardless of
/// whether either side is UTC or local (stored values are read back as UTC).
Matcher isMoment(DateTime expected) => predicate<DateTime>(
  (actual) => actual.isAtSameMomentAs(expected),
  'the same instant as $expected',
);
