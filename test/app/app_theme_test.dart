import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/theme/app_theme.dart';
import 'package:time_tracker/models/app_settings.dart';

void main() {
  test('provides exactly five accent palettes', () {
    expect(AccentPalette.values, hasLength(5));
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

  test('accent is independent of appearance mode', () {
    final light = buildTheme(AppearanceMode.light, AccentPalette.blue);
    final teal = buildTheme(AppearanceMode.light, AccentPalette.teal);
    expect(light.colorScheme.primary, isNot(teal.colorScheme.primary));
  });
}
