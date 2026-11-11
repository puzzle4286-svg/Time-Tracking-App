import 'package:flutter/material.dart';

import 'settings_controller.dart';
import 'theme/app_theme.dart';

/// Root widget: applies the persisted theme. [home] is replaced by the real
/// main screen in Phase 3.
class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key, required this.settings, required this.home});

  final SettingsController settings;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.settings;
        return MaterialApp(
          title: 'Time Tracker',
          theme: buildTheme(s.appearance, s.accent),
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
