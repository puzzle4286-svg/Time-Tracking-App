import 'package:flutter/material.dart';

/// The optional Neon look (D48), carried in the theme so any widget can ask
/// for it without passing settings around.
///
/// Off: every helper returns nothing, so widgets look exactly as without
/// Neon. On: coloured elements get a soft glow in their own colour.
@immutable
class Neon extends ThemeExtension<Neon> {
  const Neon({required this.enabled});

  final bool enabled;

  static const off = Neon(enabled: false);

  /// Whether Neon is on for [context]'s theme.
  static bool of(BuildContext context) =>
      Theme.of(context).extension<Neon>()?.enabled ?? false;

  /// Glow around a box in [color]; empty when Neon is off.
  static List<BoxShadow> boxGlow(
    BuildContext context,
    Color color, {
    double strength = 1,
  }) => of(context) ? boxGlowFor(color, strength: strength) : const [];

  /// Two layers: a tight bright halo and a wide soft one.
  static List<BoxShadow> boxGlowFor(Color color, {double strength = 1}) => [
    BoxShadow(
      color: color.withValues(alpha: (0.75 * strength).clamp(0.0, 1.0)),
      blurRadius: 6 * strength,
    ),
    BoxShadow(
      color: color.withValues(alpha: (0.45 * strength).clamp(0.0, 1.0)),
      blurRadius: 22 * strength,
      spreadRadius: 1 * strength,
    ),
  ];

  /// Glow for text and icons in [color]; null when Neon is off.
  static List<Shadow>? textGlow(BuildContext context, Color color) =>
      of(context) ? textGlowFor(color) : null;

  static List<Shadow> textGlowFor(Color color) => [
    Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8),
    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 24),
  ];

  /// Blur for painting a glow layer under a shape in a [CustomPainter].
  static const MaskFilter painterGlow = MaskFilter.blur(BlurStyle.normal, 7);

  @override
  Neon copyWith({bool? enabled}) => Neon(enabled: enabled ?? this.enabled);

  @override
  Neon lerp(Neon? other, double t) => other == null || t < 0.5 ? this : other;
}
