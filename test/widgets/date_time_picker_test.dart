import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/widgets/common/date_time_picker.dart';

void main() {
  testWidgets('accepts UTC bounds whose UTC date differs from the local date', (
    tester,
  ) async {
    // Local midnight entry end, and "now" as a UTC instant shortly after it.
    final midnight = DateTime(2026, 11, 12);
    final nowUtc = midnight.add(const Duration(minutes: 40)).toUtc();
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await pickDateTime(
              context,
              midnight,
              first: DateTime.utc(2000),
              last: nowUtc,
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time picker: keep 00:00
    await tester.pumpAndSettle();
    expect(result, midnight); // unchanged minute keeps the exact value
  });
}
