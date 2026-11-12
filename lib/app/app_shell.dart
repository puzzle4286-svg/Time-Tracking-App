import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../repositories/ui_state_store.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/insights/insights_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../services/activities/activity_service.dart';
import '../services/analytics/insight_period.dart';
import '../services/analytics/insights_service.dart';
import '../services/app_icon/app_icon_service.dart';
import '../services/goals/goal_service.dart';
import '../services/history/entry_edit_service.dart';
import '../services/history/history_service.dart';
import '../services/tracking/tracking_service.dart';
import '../util/clock.dart';
import '../widgets/data/data_section.dart';
import 'settings_controller.dart';

/// Bottom navigation between Track, History, Insights and Settings. Also reconciles
/// tracking whenever the app returns to the foreground.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.tracking,
    required this.activities,
    required this.settings,
    required this.history,
    required this.edits,
    required this.goals,
    required this.uiState,
    required this.db,
    required this.clock,
    this.data,
    this.appIcon,
  });

  final TrackingService tracking;
  final ActivityService activities;
  final SettingsController settings;
  final HistoryService history;
  final EntryEditService edits;
  final GoalService goals;
  final UiStateStore uiState;

  /// Read access for Insights.
  final DatabaseExecutor db;
  final Clock clock;

  /// Export, backup and restore in Settings; omitted in some tests.
  final DataActions? data;

  /// Launcher icon choice in Settings; Android only.
  final AppIconService? appIcon;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppLifecycleListener _lifecycle;
  int _index = 0;

  /// Selected Insights period; kept here so History can open a day in it.
  late InsightPeriod _insightsPeriod = InsightPeriod(
    InsightUnit.day,
    widget.clock.now(),
  );

  /// Everything that can change Insights numbers.
  late final Listenable _dataChanges = Listenable.merge([
    widget.tracking,
    widget.edits,
    widget.activities,
  ]);

  void _openDayInsights(DateTime day) => setState(() {
    _insightsPeriod = InsightPeriod(InsightUnit.day, day);
    _index = 2;
  });

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
    const titles = ['Track', 'History', 'Insights', 'Settings'];
    return Scaffold(
      appBar: _index == 0 ? null : AppBar(title: Text(titles[_index])),
      body: switch (_index) {
        0 => HomeScreen(
          tracking: widget.tracking,
          activities: widget.activities,
          goals: widget.goals,
          clock: widget.clock,
        ),
        1 => HistoryScreen(
          history: widget.history,
          tracking: widget.tracking,
          edits: widget.edits,
          activities: widget.activities,
          uiState: widget.uiState,
          onOpenDay: _openDayInsights,
          clock: widget.clock,
        ),
        2 => InsightsScreen(
          insights: InsightsService(widget.db, widget.clock),
          period: _insightsPeriod,
          onPeriodChanged: (p) => setState(() => _insightsPeriod = p),
          changes: _dataChanges,
          clock: widget.clock,
        ),
        _ => SafeArea(
          child: SettingsScreen(
            settings: widget.settings,
            uiState: widget.uiState,
            data: widget.data,
            appIcon: widget.appIcon,
          ),
        ),
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
            icon: Icon(Icons.view_timeline_outlined),
            selectedIcon: Icon(Icons.view_timeline),
            label: 'History',
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
