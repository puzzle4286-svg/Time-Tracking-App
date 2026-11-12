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
          theme: buildTheme(s.appearance, s.accent, neon: s.neon),
          // No Android stretch/glow when scrolling past the ends.
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
          ),
          home: home,
        );
      },
    );
  }
}
