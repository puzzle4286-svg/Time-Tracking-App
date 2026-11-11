import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/ui_state_store.dart';
import '../../services/activities/activity_service.dart';
import '../../services/history/entry_edit_service.dart';
import '../../services/history/history_service.dart';
import '../../services/tracking/time_range.dart';
import '../../services/tracking/tracking_service.dart';
import '../../util/clock.dart';
import '../../util/date_format.dart';
import '../../util/timestamps.dart';
import '../../widgets/entries/entry_editor_sheet.dart';
import '../../widgets/timeline/day_timeline.dart';

/// One continuous vertical timeline: now at the bottom, scrolling up goes back
/// day by day until the first recorded day.
///
/// Updates every second. While scrolled to the bottom it follows "now" (the
/// running block grows and older content moves up); while scrolled into the
/// past, the visible moment stays in place. The position is remembered as
/// the instant shown at the bottom edge, so it survives tab switches,
/// restarts and the passing of time.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.history,
    required this.tracking,
    required this.edits,
    required this.activities,
    required this.uiState,
    required this.clock,
  });

  final HistoryService history;

  /// Edits made from this screen; also listened to, like [activities]
  /// (renames and deletions change how history is shown).
  final EntryEditService edits;
  final ActivityService activities;

  /// Listened to so the timeline refreshes when the activity changes.
  final TrackingService tracking;
  final UiStateStore uiState;
  final Clock clock;

  static const double dayHeaderHeight = 48;
  static const double dayBottomPadding = 24;
  static const anchorKey = 'history.anchor';

  /// Within this distance of the bottom the view counts as "at now".
  static const double followThreshold = 8;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scroll = ScrollController();
  final Map<DateTime, List<DayEntry>> _cache = {};
  final Map<DateTime, Future<void>> _loading = {};
  DateTime? _firstDay;
  Timer? _ticker;

  /// The `now` the current layout was built with. Anchors must be computed
  /// against what is on screen, not against the (already newer) clock.
  late DateTime _builtNow = widget.clock.now();

  /// Bumped when cached data becomes stale, so loads that were already
  /// running cannot write outdated entries into the cache.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.tracking.addListener(_onTrackingChanged);
    widget.edits.addListener(_refreshAll);
    widget.activities.addListener(_refreshAll);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _loadFirstDay();
    _restorePosition();
  }

  @override
  void dispose() {
    widget.tracking.removeListener(_onTrackingChanged);
    widget.edits.removeListener(_refreshAll);
    widget.activities.removeListener(_refreshAll);
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---- Data -------------------------------------------------------------

  Future<void> _loadFirstDay() async {
    final first = await widget.history.firstDay();
    if (mounted) setState(() => _firstDay = first);
  }

  /// Loads [day] once; concurrent callers share the same future.
  Future<void> _ensureLoaded(DateTime day) {
    if (_cache.containsKey(day)) return Future.value();
    return _loading[day] ??= _fetch(day);
  }

  Future<void> _fetch(DateTime day) async {
    final generation = _generation;
    final entries = await widget.history.entriesForDay(day);
    if (!mounted || generation != _generation) return;
    _keepingPosition(() {
      _cache[day] = entries;
      _loading.removeWhere((key, _) => key == day);
    });
  }

  void _onTrackingChanged() {
    // A switch or midnight split only touches today and yesterday. Refresh
    // those in place (keeping the old data until the new arrives, so the
    // layout does not jump).
    _generation++;
    _loading.clear();
    for (final i in [0, 1]) {
      _loading[_dayAt(i)] = _fetch(_dayAt(i));
    }
    _loadFirstDay();
  }

  /// Any day may have changed: refetch every loaded day in place.
  void _refreshAll() {
    _generation++;
    _loading.clear();
    for (final day in _cache.keys.toList()) {
      _loading[day] = _fetch(day);
    }
    _loadFirstDay();
  }

  void _tick() {
    if (mounted) _keepingPosition(() {});
  }

  // ---- Geometry ---------------------------------------------------------

  DateTime _today() => startOfLocalDay(widget.clock.now());

  /// Day for list index [i] (0 = today, counting back).
  DateTime _dayAt(int i) {
    final t = _today();
    return DateTime(t.year, t.month, t.day - i);
  }

  int _indexOf(DateTime t) {
    final day = startOfLocalDay(t);
    var i = 0;
    while (_dayAt(i).isAfter(day)) {
      i++;
    }
    return i;
  }

  int get _dayCount {
    final first = _firstDay;
    return first == null ? 1 : _indexOf(first) + 1;
  }

  double _timelineHeight(int i, DateTime now) {
    final day = _dayAt(i);
    return DayTimeline.layoutFor(
      localDay(day),
      _cache[day] ?? const [],
      now,
    ).height;
  }

  double _extentOf(int i, DateTime now) =>
      HistoryScreen.dayHeaderHeight +
      _timelineHeight(i, now) +
      HistoryScreen.dayBottomPadding;

  bool get _followingNow =>
      !_scroll.hasClients || _scroll.offset <= HistoryScreen.followThreshold;

  /// The instant at the bottom edge of the viewport. The list is reversed,
  /// so the scroll offset is the distance from the bottom of today.
  DateTime _anchorAtBottom(DateTime now) {
    var remaining = _scroll.offset;
    for (var i = 0; i < _dayCount; i++) {
      final extent = _extentOf(i, now);
      if (remaining < extent) {
        final day = localDay(_dayAt(i));
        final layout = DayTimeline.layoutFor(
          day,
          _cache[_dayAt(i)] ?? const [],
          now,
        );
        final fromBottom = remaining - HistoryScreen.dayBottomPadding;
        if (fromBottom <= 0) return DayTimeline.visibleEnd(day, now);
        final y = layout.height - fromBottom;
        return y <= 0 ? day.start : layout.timeOf(y);
      }
      remaining -= extent;
    }
    return _firstDay ?? _today();
  }

  /// Scroll offset that puts [t] at the bottom edge. Days 0.._indexOf(t)
  /// must be loaded for this to be exact.
  double _offsetForAnchor(DateTime t, DateTime now) {
    final target = _indexOf(t);
    var offset = 0.0;
    for (var i = 0; i < target; i++) {
      offset += _extentOf(i, now);
    }
    final day = localDay(_dayAt(target));
    final layout = DayTimeline.layoutFor(
      day,
      _cache[_dayAt(target)] ?? const [],
      now,
    );
    return offset +
        HistoryScreen.dayBottomPadding +
        layout.height -
        layout.yOf(t);
  }

  /// Not clamped to `maxScrollExtent`: with lazily built days that extent
  /// is only an estimate; the scroll physics clamp after layout.
  void _jumpTo(double offset) {
    if (_scroll.hasClients) _scroll.jumpTo(offset < 0 ? 0 : offset);
  }

  /// Applies [change] (new data or a newer `now`). At the bottom the view
  /// keeps following now. Otherwise the visible content is kept in place:
  /// the on-screen position of a visible day section is measured before and
  /// after the frame and any actual shift is scrolled back. (Measuring, not
  /// predicting, because the list itself already compensates size changes of
  /// days that are not laid out.)
  void _keepingPosition(VoidCallback change) {
    final reference = _followingNow ? null : _visibleSection();
    final before = reference == null ? null : _topOf(reference);
    setState(change);
    if (reference == null || before == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final after = mounted ? _topOf(reference) : null;
      if (after == null || !_scroll.hasClients) return;
      final shift = after - before;
      if (shift.abs() > 0.01) _jumpTo(_scroll.offset - shift);
    });
  }

  final Map<DateTime, GlobalKey> _sectionKeys = {};

  GlobalKey _sectionKey(DateTime day) =>
      _sectionKeys.putIfAbsent(day, GlobalKey.new);

  /// A day section that is currently laid out and on screen.
  DateTime? _visibleSection() {
    if (!_scroll.hasClients) return null;
    final viewport =
        _scroll.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (viewport == null) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    for (final MapEntry(key: day, value: key) in _sectionKeys.entries) {
      final y = _topOf(day);
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (y == null || box == null) continue;
      if (y < bottom && y + box.size.height > top) return day;
    }
    return null;
  }

  double? _topOf(DateTime day) {
    final box =
        _sectionKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  // ---- Persistence ------------------------------------------------------

  Future<void> _restorePosition() async {
    final saved = widget.uiState.get(HistoryScreen.anchorKey);
    final micros = int.tryParse(saved ?? '');
    if (micros == null) return; // "now" or nothing saved
    await _scrollToAnchor(fromStoredTimestamp(micros));
  }

  Future<void> _scrollToAnchor(DateTime t) async {
    final target = _indexOf(t);
    for (var i = 0; i <= target; i++) {
      await _ensureLoaded(_dayAt(i));
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpTo(_offsetForAnchor(t, widget.clock.now()));
    });
  }

  bool _savePosition(ScrollEndNotification _) {
    final value = _followingNow
        ? 'now'
        : toStoredTimestamp(_anchorAtBottom(_builtNow)).toString();
    widget.uiState.set(HistoryScreen.anchorKey, value);
    return false;
  }

  // ---- Actions ----------------------------------------------------------

  Future<void> _jumpToDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: _firstDay ?? today,
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    final now = widget.clock.now();
    // Put the picked day's header at the top: anchor the bottom edge at the
    // moment that lies one viewport below the day start.
    final target = _indexOf(picked);
    for (var i = 0; i <= target; i++) {
      await _ensureLoaded(_dayAt(i));
    }
    if (!mounted || !_scroll.hasClients) return;
    var offset = 0.0;
    for (var i = 0; i <= target; i++) {
      offset += _extentOf(i, now);
    }
    _jumpTo(offset - _scroll.position.viewportDimension);
  }

  void _scrollToNow() => _scroll.animateTo(
    0,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final now = _builtNow = widget.clock.now();
    return Column(
      children: [
        // Toolbar above the timeline so it never covers entries.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _jumpToDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Jump to date'),
              ),
              TextButton.icon(
                onPressed: _scrollToNow,
                icon: const Icon(Icons.vertical_align_bottom),
                label: const Text('Now'),
              ),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _savePosition,
            child: ListView.builder(
              key: const Key('history-list'),
              controller: _scroll,
              reverse: true, // now at the bottom; scroll up into the past
              itemCount: _dayCount,
              itemBuilder: (context, i) {
                final day = _dayAt(i);
                unawaited(_ensureLoaded(day));
                return _DaySection(
                  key: ValueKey(day),
                  onEntryTap: (item) => showEntryEditor(
                    context,
                    item: item,
                    edits: widget.edits,
                    activities: widget.activities,
                    clock: widget.clock,
                  ),
                  sectionKey: _sectionKey(day),
                  day: localDay(day),
                  entries: _cache[day],
                  now: now,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.sectionKey,
    required this.onEntryTap,
    required this.day,
    required this.entries,
    required this.now,
  });

  /// Used to measure the section's on-screen position.
  final GlobalKey sectionKey;
  final ValueChanged<DayEntry> onEntryTap;
  final TimeRange day;
  final List<DayEntry>? entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final list = entries;

    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(bottom: HistoryScreen.dayBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: HistoryScreen.dayHeaderHeight,
            child: Container(
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              // "Info" will later open this day's Insights; text only for now.
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDayLabel(day.start, now),
                      style: text.titleSmall,
                    ),
                  ),
                  Text(
                    'Info',
                    style: text.labelLarge?.copyWith(color: scheme.primary),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: scheme.primary),
                ],
              ),
            ),
          ),
          DayTimeline(
            day: day,
            entries: list ?? const [],
            now: now,
            onEntryTap: onEntryTap,
          ),
        ],
      ),
    );
  }
}
