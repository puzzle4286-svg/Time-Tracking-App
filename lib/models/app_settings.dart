enum AppearanceMode { light, dark, black }

/// How colourful the app is (D59), in the order shown in Settings.
enum AppStyle {
  /// Colours as they are.
  flat,

  /// Glowing highlights (D48).
  neon,

  /// Everything in shades of grey, activities included; no accent.
  grayscale;

  /// Whether the whole app is shown without colour.
  bool get colourless => this == grayscale;
}

/// Predefined accent palettes, each defined by a Material 3 seed. Stored by
/// name, so new values can be appended without affecting saved settings.
enum AccentPalette {
  teal('Teal', 0xFF00897B),
  blue('Blue', 0xFF1E88E5),
  violet('Violet', 0xFF7E57C2),
  amber('Amber', 0xFFFFA000),
  rose('Rose', 0xFFD81B60),
  indigo('Indigo', 0xFF3949AB),
  cyan('Cyan', 0xFF00ACC1),
  green('Green', 0xFF43A047),
  lime('Lime', 0xFF9E9D24),
  orange('Orange', 0xFFF4511E),
  red('Red', 0xFFE53935),
  pink('Pink', 0xFFEC407A),
  brown('Brown', 0xFF6D4C41),
  slate('Slate', 0xFF546E7A);

  const AccentPalette(this.label, this.seed);

  final String label;

  /// ARGB seed colour.
  final int seed;
}

class AppSettings {
  const AppSettings({
    this.appearance = AppearanceMode.dark,
    this.accent = AccentPalette.teal,
    this.style = AppStyle.flat,
  });

  final AppearanceMode appearance;
  final AccentPalette accent;

  final AppStyle style;

  /// Neon look: glowing highlights (D48).
  bool get neon => style == AppStyle.neon;

  AppSettings copyWith({
    AppearanceMode? appearance,
    AccentPalette? accent,
    AppStyle? style,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    accent: accent ?? this.accent,
    style: style ?? this.style,
  );
}
