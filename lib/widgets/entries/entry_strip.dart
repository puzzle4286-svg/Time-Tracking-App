import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';

/// The look of an entry everywhere in the app: tinted background in the
/// activity colour with a thick coloured bar on the left (as in History).
class EntryStrip extends StatelessWidget {
  const EntryStrip({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border(left: BorderSide(color: color, width: 6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!Neon.of(context)) return box;
    // A glowing tube along the coloured edge (D48).
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: Neon.boxGlowFor(color, strength: 0.6),
            ),
          ),
        ),
        box,
      ],
    );
  }
}

/// A one-line entry: activity name and a trailing value (usually a duration).
class EntryStripRow extends StatelessWidget {
  const EntryStripRow({
    super.key,
    required this.color,
    required this.name,
    required this.trailing,
  });

  final Color color;
  final String name;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: EntryStrip(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
