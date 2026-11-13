import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Holds the current [AppSettings] and persists every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository, this._settings);

  final SettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  Future<void> setAppearance(AppearanceMode mode) =>
      _update(_settings.copyWith(appearance: mode));

  Future<void> setAccent(AccentPalette accent) =>
      _update(_settings.copyWith(accent: accent));

  Future<void> setStyle(AppStyle style) =>
      _update(_settings.copyWith(style: style));

  Future<void> _update(AppSettings next) async {
    // Persist first so the UI never shows a setting that was not saved.
    await _repository.save(next);
    _settings = next;
    notifyListeners();
  }
}
