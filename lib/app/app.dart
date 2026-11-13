import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'settings_controller.dart';
import 'theme/app_theme.dart';

/// Root widget: applies the persisted theme.
class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({
    super.key,
    required this.settings,
    required this.home,
    this.scaffoldMessengerKey,
  });

  final SettingsController settings;
  final Widget home;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.settings;
        return MaterialApp(
          title: 'Lifestring',
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: buildTheme(s.appearance, s.accent, style: s.style),
          // No Android stretch/glow when scrolling past the ends. Every
          // pointer drags lists, the mouse included, so the Linux build
          // swipes like the phone (D58).
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          // Grayscale shows the whole app without colour,
          // activity colours included (D59). Wraps the navigator, so sheets
          // and dialogs are included.
          builder: switch (styleFilter(s.style)) {
            final filter? => (context, child) => ColorFiltered(
              colorFilter: filter,
              child: child,
            ),
            null => null,
          },
          home: home,
        );
      },
    );
  }
}
