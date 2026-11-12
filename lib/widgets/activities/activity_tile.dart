import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';
import '../../models/activity.dart';
import '../../models/activity_icons.dart';

/// One of the eight compact grid buttons.
///
/// The active activity is shown in its full colour with a ring; all others
/// are muted (a faint tint of their colour), so the active one stands out at
/// a glance. With Neon (D48) the active tile glows in its colour and the
/// others are dark with a thin outline and icon in their colour. The tile
/// shows the activity's icon, or the first letter of its name without one.
/// [activity] is null for an empty slot (shows "+").
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
  static Color fillFor(
    ColorScheme scheme,
    Activity? activity,
    bool active, {
    bool neon = false,
  }) {
    if (activity == null) return Colors.transparent;
    final color = Color(activity.color);
    if (active) return color;
    return Color.lerp(
      neon ? scheme.surface : scheme.surfaceContainerHigh,
      color,
      neon ? neonTint : mutedTint,
    )!;
  }

  /// Inactive tile tint with Neon: darker, the outline carries the colour.
  static const double neonTint = 0.10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final neon = Neon.of(context);
    final a = activity;
    final color = a == null ? null : Color(a.color);
    final fill = fillFor(scheme, a, isActive, neon: neon);
    final foreground = a == null
        ? scheme.onSurfaceVariant
        : isActive
        ? (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : neon
        ? color!.withValues(alpha: 0.85)
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
              : neon
              ? Border.all(color: color!.withValues(alpha: 0.6), width: 1.5)
              : null,
          boxShadow: isActive && neon ? Neon.boxGlowFor(color!) : null,
        ),
        child: Material(
          color: fill,
          animationDuration: _duration,
          borderRadius: BorderRadius.circular(
            _radius - (isActive ? 3 : (neon && a != null ? 1.5 : 0)),
          ),
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
