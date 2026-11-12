import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/activity_icons.dart';

/// One of the eight compact grid buttons.
///
/// The active activity is shown in its full colour with a ring and a soft
/// glow; all others are muted (a faint tint of their colour), so the active
/// one stands out at a glance. The tile shows the activity's icon, or the
/// first letter of its name without one. [activity] is null for an empty
/// slot (shows "+").
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

  /// How much of the activity colour an inactive tile shows.
  static const double mutedTint = 0.28;

  static const _radius = 14.0;
  static const _duration = Duration(milliseconds: 200);

  /// Fill colour for [activity] in the given state (exposed for tests).
  static Color fillFor(ColorScheme scheme, Activity? activity, bool active) {
    if (activity == null) return Colors.transparent;
    final color = Color(activity.color);
    return active
        ? color
        : Color.lerp(scheme.surfaceContainerHigh, color, mutedTint)!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = activity;
    final fill = fillFor(scheme, a, isActive);
    final foreground = a == null
        ? scheme.onSurfaceVariant
        : isActive
        ? (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : scheme.onSurface.withValues(alpha: 0.75);
    final icon = a == null ? Icons.add : activityIcon(a.icon);

    return Semantics(
      button: true,
      selected: isActive,
      label: a == null
          ? 'Empty slot, tap to set up'
          : '${a.name}${isActive ? ', active' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const Key('tile-frame'),
        duration: _duration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: isActive
              ? Border.all(color: scheme.onSurface, width: 3)
              : a == null
              ? Border.all(color: scheme.outlineVariant)
              : null,
          boxShadow: isActive && a != null
              ? [
                  BoxShadow(
                    color: Color(a.color).withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: fill,
          animationDuration: _duration,
          borderRadius: BorderRadius.circular(_radius - (isActive ? 3 : 0)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox.expand(
              child: Center(
                child: icon != null
                    ? Icon(icon, color: foreground, size: isActive ? 30 : 26)
                    : Text(
                        a!.name.characters.first.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
