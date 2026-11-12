import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/services/app_icon/app_icon_service.dart';
import 'package:time_tracker/widgets/settings/app_icon_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Fake of android/.../AppIcon.kt; Android's default is Neon.
  late String enabled;
  late List<MethodCall> calls;

  setUp(() {
    enabled = 'neon';
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppIconService.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'current':
              return enabled;
            case 'set':
              enabled = call.arguments as String;
              return null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppIconService.channel, null),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppIconSection(service: AppIconService())),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool? isSelected(WidgetTester tester, AppIconChoice icon) => tester
      .widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.label == '${icon.label} app icon',
        ),
      )
      .properties
      .selected;

  testWidgets('shows both icons with Neon selected by default', (tester) async {
    await pump(tester);
    expect(find.text('Neon'), findsOneWidget);
    expect(find.text('Flat'), findsOneWidget);
    expect(isSelected(tester, AppIconChoice.neon), isTrue);
    expect(isSelected(tester, AppIconChoice.flat), isFalse);
  });

  testWidgets('tapping an icon switches it on Android', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('app-icon-flat')));
    await tester.pumpAndSettle();

    expect(enabled, 'flat');
    expect(isSelected(tester, AppIconChoice.flat), isTrue);
    expect(find.textContaining('The new icon appears'), findsOneWidget);

    // Tapping the selected icon again does nothing.
    calls.clear();
    await tester.tap(find.byKey(const Key('app-icon-flat')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('shows the stored choice', (tester) async {
    enabled = 'flat';
    await pump(tester);
    expect(isSelected(tester, AppIconChoice.flat), isTrue);
  });

  test('unknown values fall back to Neon', () {
    expect(AppIconChoice.parse('other'), AppIconChoice.neon);
    expect(AppIconChoice.parse(null), AppIconChoice.neon);
  });
}
