import 'package:flutter/material.dart';

/// Root widget. Theme, storage and tracking are wired in during Phase 1.
class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Tracker',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Time Tracker'))),
    );
  }
}
