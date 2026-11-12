import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import 'neon.dart';

/// Builds the Material 3 theme for an appearance mode and accent palette.
/// [neon] adds the [Neon] extension that widgets use for their glow.
ThemeData buildTheme(
  AppearanceMode mode,
  AccentPalette accent, {
  bool neon = false,
}) {
  final brightness = mode == AppearanceMode.light
      ? Brightness.light
      : Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: Color(accent.seed),
    brightness: brightness,
  );
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
