enum AppearanceMode { light, dark, black }

/// The five predefined accent palettes, each defined by a Material 3 seed.
enum AccentPalette {
  teal('Teal', 0xFF00897B),
  blue('Blue', 0xFF1E88E5),
  violet('Violet', 0xFF7E57C2),
  amber('Amber', 0xFFFFA000),
  rose('Rose', 0xFFD81B60);

  const AccentPalette(this.label, this.seed);

  final String label;

  /// ARGB seed colour.
  final int seed;
}

class AppSettings {
  const AppSettings({
    this.appearance = AppearanceMode.dark,
    this.accent = AccentPalette.teal,
  });

  final AppearanceMode appearance;
  final AccentPalette accent;

  AppSettings copyWith({AppearanceMode? appearance, AccentPalette? accent}) =>
      AppSettings(
        appearance: appearance ?? this.appearance,
        accent: accent ?? this.accent,
      );
}
