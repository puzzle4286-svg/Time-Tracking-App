import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import 'neon.dart';

/// Colour matrix that turns any colour into its grey of equal luminance
/// (Rec. 709 weights). Applied to the whole app, and to the home-screen
/// widget's tiles, in Grayscale (D59).
const List<double> grayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// The whole-app colour filter for [style], or null for none (D59).
ColorFilter? styleFilter(AppStyle style) => switch (style) {
  AppStyle.grayscale => const ColorFilter.matrix(grayscaleMatrix),
  AppStyle.flat || AppStyle.neon => null,
};

/// Builds the Material 3 theme for an appearance mode, accent palette and
/// style. Neon adds the [Neon] extension that widgets use for their glow;
/// Grayscale ignores the accent (D59).
ThemeData buildTheme(
  AppearanceMode mode,
  AccentPalette accent, {
  AppStyle style = AppStyle.flat,
}) {
  final brightness = mode == AppearanceMode.light
      ? Brightness.light
      : Brightness.dark;
  final neon = style == AppStyle.neon;
  var scheme = switch (style) {
    AppStyle.grayscale => ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    ),
    AppStyle.flat || AppStyle.neon => ColorScheme.fromSeed(
      seedColor: Color(accent.seed),
      brightness: brightness,
    ),
  };
  if (mode == AppearanceMode.black) {
    // True black for OLED; containers stay just distinguishable from it.
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
      surfaceContainerHigh: const Color(0xFF181818),
      surfaceContainerHighest: const Color(0xFF202020),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    extensions: [Neon(enabled: neon)],
    navigationBarTheme: neon
        ? NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? IconThemeData(
                      color: scheme.onSecondaryContainer,
                      shadows: Neon.textGlowFor(scheme.primary),
                    )
                  : IconThemeData(color: scheme.onSurfaceVariant),
            ),
          )
        : null,
  );
}
