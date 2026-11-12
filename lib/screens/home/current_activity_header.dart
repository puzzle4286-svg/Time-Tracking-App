import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';
import '../../models/activity.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../util/duration_format.dart';
import '../../widgets/common/activity_dot.dart';

/// Shows the active activity, its session duration and today's total.
///
/// The one-second timer only repaints. Durations always come from stored
/// timestamps; when the local day ends while visible, it asks the service to
/// reconcile so the new day gets its own entry.
class CurrentActivityHeader extends StatefulWidget {
  const CurrentActivityHeader({
    super.key,
    required this.tracking,
    required this.activity,
    required this.clock,
  });

  final TrackingService tracking;

  /// The active activity with up-to-date name and colour.
  final Activity activity;
  final Clock clock;

  @override
  State<CurrentActivityHeader> createState() => _CurrentActivityHeaderState();
}

class _CurrentActivityHeaderState extends State<CurrentActivityHeader> {
  Timer? _ticker;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final now = widget.clock.now();
    if (!now.isBefore(widget.tracking.current.dayEnd) && !_reconciling) {
      _reconciling = true;
      try {
        await widget.tracking.reconcile();
      } finally {
        _reconciling = false;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.tracking.current;
    final now = widget.clock.now();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const tabular = [FontFeature.tabularFigures()];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ActivityDot(color: Color(widget.activity.color), size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.activity.name,
                  key: const Key('current-activity-name'),
                  style: text.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatClock(session.sessionDuration(now)),
            key: const Key('session-duration'),
            style: text.displayMedium?.copyWith(
              fontFeatures: tabular,
              color: scheme.primary,
              fontWeight: FontWeight.w500,
              shadows: Neon.textGlow(context, scheme.primary),
            ),
          ),
          Text(
            'Today ${formatTotal(session.todayTotal(now))}',
            key: const Key('today-total'),
            style: text.titleMedium?.copyWith(
              fontFeatures: tabular,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
