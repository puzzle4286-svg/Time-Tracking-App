import 'package:flutter/material.dart';

import '../../models/activity.dart';

/// One of the eight compact grid buttons, filled with the activity's colour.
/// Shows a pause icon while the activity is running and a play icon
/// otherwise. [activity] is null for an empty slot (shows "+").
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.activity,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final Activity? activity;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = activity;
    final fill = a == null ? Colors.transparent : Color(a.color);
    final iconColor = a == null
        ? scheme.onSurfaceVariant
        : ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final border = isActive
        ? BorderSide(color: scheme.onSurface, width: 3)
        : a == null
        ? BorderSide(color: scheme.outlineVariant)
        : BorderSide.none;

    return Semantics(
      button: true,
      selected: isActive,
      label: a == null
          ? 'Empty slot, tap to set up'
          : '${a.name}${isActive ? ', active' : ''}',
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.expand(
            child: Icon(
              a == null
                  ? Icons.add
                  : isActive
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: iconColor,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
