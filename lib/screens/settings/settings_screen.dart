import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/settings_controller.dart';
import '../../models/app_settings.dart';
import '../../repositories/ui_state_store.dart';
import '../../services/app_icon/app_icon_service.dart';
import '../../widgets/data/data_section.dart';
import '../../widgets/settings/app_icon_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.uiState,
    this.data,
    this.appIcon,
  });

  final SettingsController settings;

  /// Remembers the accent row's scroll position across tabs and restarts.
  final UiStateStore uiState;

  /// Export, backup and restore; the section is hidden when null.
  final DataActions? data;

  /// Launcher icon choice; the section is hidden when null (not Android).
  final AppIconService? appIcon;

  static const accentScrollKey = 'settings.accentScroll';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _accentScroll = ScrollController(
    initialScrollOffset:
        widget.uiState.getDouble(SettingsScreen.accentScrollKey) ?? 0,
  );

  @override
  void dispose() {
    _accentScroll.dispose();
    super.dispose();
  }

  bool _saveAccentScroll(ScrollEndNotification n) {
    widget.uiState.set(
      SettingsScreen.accentScrollKey,
      n.metrics.pixels.toStringAsFixed(1),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final current = settings.settings;
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text('Appearance', style: text.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<AppearanceMode>(
              segments: const [
                ButtonSegment(
                  value: AppearanceMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppearanceMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: AppearanceMode.black,
                  label: Text('Black'),
                  icon: Icon(Icons.contrast),
                ),
              ],
              selected: {current.appearance},
              onSelectionChanged: (s) => settings.setAppearance(s.single),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('neon-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Neon'),
              subtitle: const Text('Glowing highlights'),
              value: current.neon,
              onChanged: settings.setNeon,
            ),
            const SizedBox(height: 24),
            Text('Accent colour', style: text.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: NotificationListener<ScrollEndNotification>(
                onNotification: _saveAccentScroll,
                child: ListView.separated(
                  key: const Key('accent-list'),
                  controller: _accentScroll,
                  scrollDirection: Axis.horizontal,
                  itemCount: AccentPalette.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final accent = AccentPalette.values[i];
                    return _AccentSwatch(
                      accent: accent,
                      selected: accent == current.accent,
                      onTap: () => settings.setAccent(accent),
                    );
                  },
                ),
              ),
            ),
            if (widget.appIcon case final appIcon?) ...[
              const SizedBox(height: 24),
              AppIconSection(service: appIcon),
            ],
            if (widget.data case final data?) ...[
              const SizedBox(height: 24),
              DataSection(actions: data),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text(appName),
              subtitle: Text(
                'Version $appVersion\nAll data is stored only on this device.',
              ),
              isThreeLine: true,
            ),
          ],
        );
      },
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentPalette accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: accent.label,
      excludeSemantics: true, // the visible label would be read twice
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(accent.seed),
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: scheme.onSurface, width: 3)
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(accent.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
