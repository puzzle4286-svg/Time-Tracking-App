import 'package:flutter/material.dart';

import '../../services/app_icon/app_icon_service.dart';

/// "App icon" in Settings: the launcher icons side by side; tap to switch.
class AppIconSection extends StatefulWidget {
  const AppIconSection({super.key, required this.service});

  final AppIconService service;

  @override
  State<AppIconSection> createState() => _AppIconSectionState();
}

class _AppIconSectionState extends State<AppIconSection> {
  /// Null until Android has answered (or if it could not).
  AppIconChoice? _current;

  @override
  void initState() {
    super.initState();
    widget.service.current().then(
      (c) {
        if (mounted) setState(() => _current = c);
      },
      onError: (Object _) {}, // options stay disabled
    );
  }

  Future<void> _choose(AppIconChoice icon) async {
    if (icon == _current) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.set(icon);
      if (!mounted) return;
      setState(() => _current = icon);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The new icon appears after you leave the app.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not change the icon: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('App icon', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final icon in AppIconChoice.values) ...[
              _IconOption(
                icon: icon,
                selected: icon == _current,
                onTap: _current == null ? null : () => _choose(icon),
              ),
              const SizedBox(width: 20),
            ],
          ],
        ),
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppIconChoice icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${icon.label} app icon',
      excludeSemantics: true,
      child: InkWell(
        key: Key('app-icon-${icon.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Image.asset(icon.preview, width: 64, height: 64),
              ),
              const SizedBox(height: 4),
              Text(icon.label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
