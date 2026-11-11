import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../services/activities/activity_service.dart';
import '../services/tracking/tracking_service.dart';
import '../util/clock.dart';
import 'settings_controller.dart';

/// Bottom navigation between Track, Insights and Settings. Also reconciles
/// tracking whenever the app returns to the foreground.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.tracking,
    required this.activities,
    required this.settings,
    required this.clock,
  });

  final TrackingService tracking;
  final ActivityService activities;
  final SettingsController settings;
  final Clock clock;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppLifecycleListener _lifecycle;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: widget.tracking.reconcile);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Track', 'Insights', 'Settings'];
    return Scaffold(
      appBar: _index == 0 ? null : AppBar(title: Text(titles[_index])),
      body: switch (_index) {
        0 => HomeScreen(
          tracking: widget.tracking,
          activities: widget.activities,
          clock: widget.clock,
        ),
        1 => const InsightsScreen(),
        _ => SafeArea(child: SettingsScreen(settings: widget.settings)),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
