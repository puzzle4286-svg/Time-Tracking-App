import 'package:flutter/material.dart';

import '../../app/theme/neon.dart';

/// The small coloured circle that stands for an activity in lists, pickers
/// and headers. Glows in its colour with Neon (D48).
class ActivityDot extends StatelessWidget {
  const ActivityDot({super.key, required this.color, this.size = 12});

  final Color color;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Strong for its size: a weaker glow is invisible on a small dot.
        boxShadow: Neon.boxGlow(context, color, strength: 1.1),
      ),
    );
  }
}
