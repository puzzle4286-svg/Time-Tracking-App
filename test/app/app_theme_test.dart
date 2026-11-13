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
      style: AppStyle.neon,
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

  group('styles (D59)', () {
    test('grayscale has no colour and ignores the accent', () {
      for (final mode in AppearanceMode.values) {
        final teal = buildTheme(
          mode,
          AccentPalette.teal,
          style: AppStyle.grayscale,
        ).colorScheme;
        final rose = buildTheme(
          mode,
          AccentPalette.rose,
          style: AppStyle.grayscale,
        ).colorScheme;
        expect(teal, rose);
        for (final c in [teal.primary, teal.surface, teal.secondaryContainer]) {
          expect(_isGrey(c), isTrue, reason: '$mode $c');
        }
      }
      // Dark and Black still differ.
      expect(
        buildTheme(
          AppearanceMode.dark,
          AccentPalette.teal,
          style: AppStyle.grayscale,
        ).colorScheme.surface,
        isNot(Colors.black),
      );
    });

    test('only Grayscale has a whole-app filter', () {
      expect(styleFilter(AppStyle.grayscale), isNotNull);
      expect(styleFilter(AppStyle.flat), isNull);
      expect(styleFilter(AppStyle.neon), isNull);
    });

    test('only Neon turns the glow on', () {
      for (final style in AppStyle.values) {
        final theme = buildTheme(
          AppearanceMode.dark,
          AccentPalette.teal,
          style: style,
        );
        expect(theme.extension<Neon>()?.enabled, style == AppStyle.neon);
      }
    });
  });
}

bool _isGrey(Color c) => (c.r - c.g).abs() < 0.02 && (c.g - c.b).abs() < 0.02;
