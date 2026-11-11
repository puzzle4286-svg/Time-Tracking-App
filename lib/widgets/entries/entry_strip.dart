import 'package:flutter/material.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border(left: BorderSide(color: color, width: 6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(padding: padding, child: child),
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
