import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/settings_controller.dart';
import '../../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 24),
            Text('Accent colour', style: text.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final accent in AccentPalette.values)
                  _AccentSwatch(
                    accent: accent,
                    selected: accent == current.accent,
                    onTap: () => settings.setAccent(accent),
                  ),
              ],
            ),
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
