import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/activity.dart';
import '../../services/activities/activity_service.dart';
import '../../widgets/activities/activity_tile.dart';

/// Rearranges the 4×2 grid: drag a tile onto another slot, or tap one tile
/// and then its destination. Dropping on an occupied slot swaps the two;
/// dropping on an empty slot moves it there. Every move is saved at once.
class ArrangeGridPage extends StatefulWidget {
  const ArrangeGridPage({super.key, required this.activities});

  final ActivityService activities;

  @override
  State<ArrangeGridPage> createState() => _ArrangeGridPageState();
}

class _ArrangeGridPageState extends State<ArrangeGridPage> {
  /// Position picked by a first tap, waiting for its destination.
  int? _picked;

  static const double _tileHeight = 72;

  Future<void> _move(int from, int to) async {
    setState(() => _picked = null);
    final activity = widget.activities.atPosition(from);
    if (activity == null || from == to) return;
    unawaited(HapticFeedback.selectionClick());
    try {
      await widget.activities.move(activity.id, to);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not move it: $e')));
    }
  }

  void _tap(int position) {
    final picked = _picked;
    if (picked == null) {
      // Only an activity can be picked up; an empty slot is a destination.
      if (widget.activities.atPosition(position) != null) {
        setState(() => _picked = position);
      }
    } else if (picked == position) {
      setState(() => _picked = null);
    } else {
      _move(picked, position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Arrange activities')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.activities,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _picked == null
                      ? 'Drag a tile to another slot, or tap a tile and then '
                            'where it should go. Your history is not affected.'
                      : 'Now tap where '
                            '${widget.activities.atPosition(_picked!)?.name} '
                            'should go.',
                  key: const Key('arrange-hint'),
                  style: text.bodyMedium,
                ),
                const Spacer(),
                for (var row = 0; row < Activity.gridRows; row++)
                  SizedBox(
                    height: _tileHeight + 6,
                    child: Row(
                      children: [
                        for (var col = 0; col < Activity.gridColumns; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _slot(
                                row * Activity.gridColumns + col + 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(int position) {
    final activity = widget.activities.atPosition(position);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget tile({bool highlighted = false}) => ActivityTile(
          activity: activity,
          // The picked tile is drawn like the active one, so it stands out.
          isActive: highlighted || _picked == position,
          onTap: () => _tap(position),
          onLongPress: () => _tap(position),
        );

        return DragTarget<int>(
          onWillAcceptWithDetails: (d) => d.data != position,
          onAcceptWithDetails: (d) => _move(d.data, position),
          builder: (context, candidates, _) {
            final hovered = candidates.isNotEmpty;
            final child = DecoratedBox(
              key: Key('arrange-slot-$position'),
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: hovered
                    ? Border.all(color: scheme.primary, width: 3)
                    : null,
              ),
              child: tile(),
            );
            if (activity == null) return child;
            return Draggable<int>(
              data: position,
              onDragStarted: () => setState(() => _picked = null),
              feedback: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: tile(highlighted: true),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: tile()),
              child: child,
            );
          },
        );
      },
    );
  }
}
