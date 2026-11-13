import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/activity_icons.dart';
import '../common/activity_dot.dart';

/// "Which activity?": every grid activity with what it covers, for when it
/// is unclear where a part of the day belongs. Tapping one closes the sheet
/// and calls [onSelect] with it; a long press closes it and calls [onEdit]
/// (the same as long-pressing the tile).
Future<void> showActivityGuide(
  BuildContext context, {
  required List<Activity> activities,
  required int activeId,
  required ValueChanged<Activity> onSelect,
  required ValueChanged<Activity> onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ActivityGuide(
      activities: activities,
      activeId: activeId,
      onSelect: onSelect,
      onEdit: onEdit,
    ),
  );
}

class _ActivityGuide extends StatelessWidget {
  const _ActivityGuide({
    required this.activities,
    required this.activeId,
    required this.onSelect,
    required this.onEdit,
  });

  final List<Activity> activities;
  final int activeId;
  final ValueChanged<Activity> onSelect;
  final ValueChanged<Activity> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: _PullDownToClose(
        onClose: () => Navigator.of(context).pop(),
        child: ListView(
          shrinkWrap: true,
          // Always draggable, and clamping so that pulling down at the top
          // reports overscroll (used to close the sheet) on every platform.
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            bottom: 16 + math.max(0, MediaQuery.viewPaddingOf(context).bottom),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Which activity?', style: theme.textTheme.titleLarge),
            ),
            for (final a in activities)
              ListTile(
                key: Key('guide-activity-${a.id}'),
                leading: a.icon != null && activityIcons[a.icon] != null
                    ? Icon(activityIcons[a.icon], color: Color(a.color))
                    : SizedBox(
                        width: 24,
                        child: Center(
                          child: ActivityDot(color: Color(a.color), size: 14),
                        ),
                      ),
                title: Text(a.name),
                subtitle: Text(
                  a.description ?? 'No description yet. Long-press to add one.',
                  style: a.description == null
                      ? TextStyle(color: muted, fontStyle: FontStyle.italic)
                      : null,
                ),
                trailing: a.id == activeId
                    ? Text('Running', style: TextStyle(color: muted))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(a);
                },
                onLongPress: () {
                  Navigator.of(context).pop();
                  onEdit(a);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Closes the sheet when the list inside is pulled down from its top, so a
/// downward swipe anywhere on the list works like dragging the handle. A
/// list that is scrolled down scrolls back up first.
class _PullDownToClose extends StatefulWidget {
  const _PullDownToClose({required this.onClose, required this.child});

  /// Downward pull past the top, in logical pixels, that closes the sheet.
  static const double distance = 48;

  /// Downward fling speed at the top that closes the sheet.
  static const double velocity = 700;

  final VoidCallback onClose;
  final Widget child;

  @override
  State<_PullDownToClose> createState() => _PullDownToCloseState();
}

class _PullDownToCloseState extends State<_PullDownToClose> {
  double _pulled = 0;
  bool _closed = false;

  /// Whether the current drag began with the list at its top.
  bool _startedAtTop = true;

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose();
  }

  bool _onNotification(ScrollNotification n) {
    if (n.depth != 0) return false;
    switch (n) {
      case ScrollStartNotification():
        _pulled = 0;
        _startedAtTop = n.metrics.extentBefore == 0;
      case OverscrollNotification(:final overscroll, :final dragDetails)
          when overscroll < 0:
        if (dragDetails != null) {
          _pulled -= overscroll;
          if (_pulled >= _PullDownToClose.distance) _close();
        } else if (_startedAtTop && n.velocity <= -_PullDownToClose.velocity) {
          // A downward fling that reached the top while still fast.
          _close();
        }
      case ScrollEndNotification(:final dragDetails):
        final v = dragDetails?.primaryVelocity ?? 0;
        if (_startedAtTop &&
            n.metrics.extentBefore == 0 &&
            v >= _PullDownToClose.velocity) {
          _close();
        }
        _pulled = 0;
      default:
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
