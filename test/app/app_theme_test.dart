import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/theme/app_theme.dart';
import 'package:time_tracker/app/theme/neon.dart';
import 'package:time_tracker/models/app_settings.dart';

void main() {
  test('provides the predefined accent palettes with unique names', () {
    expect(AccentPalette.values.length, greaterThanOrEqualTo(5));
    final labels = AccentPalette.values.map((a) => a.label).toSet();
    expect(labels, hasLength(AccentPalette.values.length));
    final seeds = AccentPalette.values.map((a) => a.seed).toSet();
    expect(seeds, hasLength(AccentPalette.values.length));
  });

  test('light and dark modes have the matching brightness', () {
    expect(
      buildTheme(AppearanceMode.light, AccentPalette.teal).brightness,
      Brightness.light,
    );
    expect(
      buildTheme(AppearanceMode.dark, AccentPalette.teal).brightness,
      Brightness.dark,
    );
  });

  test('black mode uses a truly black background', () {
    for (final accent in AccentPalette.values) {
      final theme = buildTheme(AppearanceMode.black, accent);
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.surface, Colors.black);
    }
  });

  test('dark mode is not black', () {
    final theme = buildTheme(AppearanceMode.dark, AccentPalette.teal);
    expect(theme.colorScheme.surface, isNot(Colors.black));
  });

  test('neon is off by default and carried in the theme when on', () {
    final plain = buildTheme(AppearanceMode.dark, AccentPalette.teal);
    final neon = buildTheme(
      AppearanceMode.dark,
      AccentPalette.teal,
      neon: true,
    );
    expect(plain.extension<Neon>()?.enabled, isFalse);
    expect(neon.extension<Neon>()?.enabled, isTrue);
    // Neon adds glow only; colours stay the same.
    expect(neon.colorScheme, plain.colorScheme);
  });

  test('accent is independent of appearance mode', () {
    final light = buildTheme(AppearanceMode.light, AccentPalette.blue);
    final teal = buildTheme(AppearanceMode.light, AccentPalette.teal);
    expect(light.colorScheme.primary, isNot(teal.colorScheme.primary));
  });
}
