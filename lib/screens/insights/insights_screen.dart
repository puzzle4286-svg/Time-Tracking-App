import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/analytics/insight_period.dart';
import '../../services/analytics/insights_service.dart';
import '../../util/clock.dart';
import '../../util/duration_format.dart';
import '../../widgets/charts/comparison_bars.dart';
import '../../widgets/charts/donut_chart.dart';
import '../../widgets/common/activity_dot.dart';

/// Activity distribution and period comparison for one selected period.
/// The period selector at the top drives both charts.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    super.key,
    required this.insights,
    required this.period,
    required this.onPeriodChanged,
    required this.changes,
    required this.clock,
  });

  final InsightsService insights;
  final InsightPeriod period;
  final ValueChanged<InsightPeriod> onPeriodChanged;

  /// Anything that can change the numbers (tracking, edits, activities).
  final Listenable changes;
  final Clock clock;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightsData? _data;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.changes.addListener(_load);
    // A period in progress grows while an activity runs.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.period.isInProgress(widget.clock.now())) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(InsightsScreen old) {
    super.didUpdateWidget(old);
    if (old.changes != widget.changes) {
      old.changes.removeListener(_load);
      widget.changes.addListener(_load);
    }
    if (old.period.unit != widget.period.unit ||
        old.period.anchor != widget.period.anchor) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.changes.removeListener(_load);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final period = widget.period;
    final data = await widget.insights.load(period);
    if (mounted && identical(period, widget.period)) {
      setState(() => _data = data);
    }
  }

  void _select(InsightPeriod p) => widget.onPeriodChanged(p);

  @override
  Widget build(BuildContext context) {
    final now = widget.clock.now();
    final period = widget.period;
    final data = _data?.period == period ? _data : null;
    final isAll = period.unit == InsightUnit.all;
    final isCurrent = period.isInProgress(now);
    final text = Theme.of(context).textTheme;

    // The period selector stays fixed at the top; only the results scroll.
    final selector = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SegmentedButton<InsightUnit>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: InsightUnit.day, label: Text('Day')),
              ButtonSegment(value: InsightUnit.week, label: Text('Week')),
              ButtonSegment(value: InsightUnit.month, label: Text('Month')),
              ButtonSegment(value: InsightUnit.year, label: Text('Year')),
              ButtonSegment(value: InsightUnit.all, label: Text('All')),
            ],
            selected: {period.unit},
            onSelectionChanged: (s) => _select(InsightPeriod(s.single, now)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: isAll ? null : () => _select(period.previous),
              ),
              Expanded(
                child: TextButton(
                  // Tapping the label returns to the current period.
                  onPressed: isCurrent
                      ? null
                      : () => _select(InsightPeriod(period.unit, now)),
                  child: Text(
                    period.label(now),
                    key: const Key('insights-period'),
                    style: text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: isAll || isCurrent || period.next.isFuture(now)
                    ? null
                    : () => _select(period.next),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      children: [
        selector,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (data == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _Section(
                  title: 'Distribution',
                  child: _Distribution(data: data, now: now),
                ),
                if (data.comparison != null) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title:
                        '${period.relativeName(now)} vs '
                        '${period.previous.relativeName(now)}',
                    child: _Comparison(data: data, now: now),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.data, required this.now});

  final InsightsData data;
  final DateTime now;

  static String _percent(double f) {
    final p = f * 100;
    if (p > 0 && p < 1) return '<1%';
    return '${p.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final shares = data.distribution;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        DonutChart(
          values: [for (final s in shares) s.duration.inSeconds.toDouble()],
          colors: [for (final s in shares) Color(s.activity.color)],
        ),
        const SizedBox(height: 16),
        for (final s in shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                ActivityDot(color: Color(s.activity.color)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.activity.name)),
                Text(formatTotal(s.duration)),
                SizedBox(
                  width: 52,
                  child: Text(
                    _percent(s.fraction),
                    key: ValueKey('share-${s.activity.id}'),
                    textAlign: TextAlign.right,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.data, required this.now});

  final InsightsData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = data.comparison!;
    final period = data.period;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nothing tracked in either period.')),
          )
        else
          ComparisonBars(
            rows: c.rows,
            currentLabel: period.relativeName(now),
            previousLabel: period.previous.relativeName(now),
          ),
      ],
    );
  }
}
