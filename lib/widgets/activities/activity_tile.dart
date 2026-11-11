import 'package:flutter/material.dart';

import '../../models/activity.dart';

/// One of the eight grid buttons. [activity] is null for an empty slot.
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
    final text = Theme.of(context).textTheme;
    final a = activity;

    final background = isActive
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = isActive ? scheme.onPrimaryContainer : scheme.onSurface;
    final border = isActive
        ? BorderSide(color: scheme.primary, width: 2)
        : a == null
        ? BorderSide(color: scheme.outlineVariant)
        : BorderSide.none;

    return Semantics(
      button: true,
      selected: isActive,
      child: Material(
        color: a == null ? Colors.transparent : background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        // Fill the whole grid cell, whatever the content height.
        child: SizedBox.expand(
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: a == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to set up',
                            textAlign: TextAlign.center,
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(a.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          a.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: text.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: isActive ? FontWeight.w700 : null,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 6),
                          Icon(Icons.play_arrow_rounded, color: scheme.primary),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
