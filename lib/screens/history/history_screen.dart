import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/history/history_service.dart';
import '../../services/tracking/durations.dart';
import '../../services/tracking/time_range.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import '../../widgets/timeline/day_timeline.dart';

/// One continuous vertical timeline: now at the bottom, scrolling up goes back
/// day by day until the first recorded day. Block heights are proportional to
/// time, so long activities take more space.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.history,
    required this.tracking,
    required this.clock,
  });

  final HistoryService history;

  /// Listened to so the timeline refreshes when the activity changes.
  final TrackingService tracking;
  final Clock clock;

  static const double dayHeaderHeight = 48;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scroll = ScrollController();
  final Map<DateTime, List<DayEntry>> _cache = {};
  final Set<DateTime> _loading = {};
  DateTime? _firstDay;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.tracking.addListener(_onTrackingChanged);
    // Repaints the running block; all data comes from stored timestamps.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _loadFirstDay();
  }

  @override
  void dispose() {
    widget.tracking.removeListener(_onTrackingChanged);
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirstDay() async {
    final first = await widget.history.firstDay();
    if (mounted) setState(() => _firstDay = first);
  }

  void _onTrackingChanged() {
    // Switching or midnight splitting only changes today (and possibly
    // yesterday right after midnight); cheapest correct choice: drop all.
    setState(_cache.clear);
    _loadFirstDay();
  }

  DateTime _today() => startOfLocalDay(widget.clock.now());

  /// Day for list index [i] (0 = today, counting back).
  DateTime _dayAt(int i) {
    final t = _today();
    return DateTime(t.year, t.month, t.day - i);
  }

  int get _dayCount {
    final first = _firstDay;
    if (first == null) return 1;
    var n = 1;
    final t = _today();
    while (DateTime(t.year, t.month, t.day - n + 1).isAfter(first)) {
      n++;
    }
    return n;
  }

  Future<void> _ensureLoaded(DateTime day) async {
    if (_cache.containsKey(day) || !_loading.add(day)) return;
    final entries = await widget.history.entriesForDay(day);
    _loading.remove(day);
    if (mounted) setState(() => _cache[day] = entries);
  }

  double _extentOf(int i, DateTime now) =>
      HistoryScreen.dayHeaderHeight +
      DayTimeline.heightFor(localDay(_dayAt(i)), now) +
      24; // bottom padding of a day

  Future<void> _jumpToDate() async {
    final first = _firstDay ?? _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _today(),
      firstDate: first,
      lastDate: _today(),
    );
    if (picked == null || !mounted) return;
    final now = widget.clock.now();
    // The list is reversed: offset 0 is now; day i starts after days 0..i-1.
    var offset = 0.0;
    for (var i = 0; _dayAt(i).isAfter(startOfLocalDay(picked)); i++) {
      offset += _extentOf(i, now);
    }
    // Show the picked day's header at the top of the viewport.
    final target =
        offset +
        _extentOf(_indexOf(picked), now) -
        _scroll.position.viewportDimension;
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  int _indexOf(DateTime day) {
    var i = 0;
    while (_dayAt(i).isAfter(startOfLocalDay(day))) {
      i++;
    }
    return i;
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock.now();
    return Stack(
      children: [
        ListView.builder(
          key: const Key('history-list'),
          controller: _scroll,
          reverse: true, // now at the bottom; scroll up into the past
          itemCount: _dayCount,
          itemBuilder: (context, i) {
            final day = _dayAt(i);
            unawaited(_ensureLoaded(day));
            return _DaySection(
              key: ValueKey(day),
              day: localDay(day),
              entries: _cache[day],
              now: now,
            );
          },
        ),
        Positioned(
          right: 16,
          top: 8,
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _jumpToDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Jump to date'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: const Text('Now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.entries,
    required this.now,
  });

  final TimeRange day;
  final List<DayEntry>? entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final list = entries;
    final total = list == null
        ? null
        : trackedInRange(list.map((e) => e.entry), day, now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: HistoryScreen.dayHeaderHeight,
            child: Container(
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Text(
                total == null
                    ? formatDayLabel(day.start, now)
                    : '${formatDayLabel(day.start, now)} · '
                          '${formatTotal(total)} tracked',
                style: text.titleSmall,
              ),
            ),
          ),
          DayTimeline(day: day, entries: list ?? const [], now: now),
        ],
      ),
    );
  }
}
