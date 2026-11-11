import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/app.dart';

void main() {
  testWidgets('app shell builds', (tester) async {
    await tester.pumpWidget(const TimeTrackerApp());
    expect(find.text('Time Tracker'), findsOneWidget);
  });
}
