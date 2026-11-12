import 'package:flutter/material.dart';

import '../../models/activity_colors.dart';
import '../../models/activity_icons.dart';
import '../../services/activities/activity_service.dart';

/// Values entered in the activity editor.
typedef ActivityDraft = ({String name, int color, String? icon});

/// Bottom sheet for setting up an empty slot or editing an activity.
/// Returns the entered values, or null if cancelled. With [onDelete], a
/// "Delete activity" button closes the sheet and calls it.
Future<ActivityDraft?> showActivityEditor(
  BuildContext context, {
  required String title,
  required String initialName,
  required int initialColor,
  String? initialIcon,
  VoidCallback? onDelete,
  VoidCallback? onGoals,
}) {
  return showModalBottomSheet<ActivityDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ActivityEditor(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
      initialIcon: initialIcon,
      onDelete: onDelete,
      onGoals: onGoals,
    ),
  );
}

class _ActivityEditor extends StatefulWidget {
  const _ActivityEditor({
    required this.title,
    required this.initialName,
    required this.initialColor,
    required this.initialIcon,
    required this.onDelete,
    required this.onGoals,
  });

  final String title;
  final String initialName;
  final int initialColor;
  final String? initialIcon;
  final VoidCallback? onDelete;
  final VoidCallback? onGoals;

  @override
  State<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<_ActivityEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late int _color = widget.initialColor;
  late String? _icon = widget.initialIcon;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop<ActivityDraft>((name: _name.text.trim(), color: _color, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        // Scrolls when the icon list does not fit (small screens, keyboard).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.initialName.isEmpty,
                maxLength: ActivityService.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => ActivityService.validateName(v ?? ''),
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              Text('Colour', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in activityColors)
                    InkResponse(
                      onTap: () => setState(() => _color = c),
                      radius: 24,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: c == _color
                              ? Border.all(color: scheme.onSurface, width: 3)
                              : null,
                        ),
                        child: c == _color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _IconPicker(
                selected: _icon,
                color: Color(_color),
                onSelected: (key) => setState(() => _icon = key),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save')),
              if (widget.onGoals != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onGoals!();
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Goals'),
                ),
              ],
              if (widget.onDelete != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete!();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete activity'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "None" plus every icon in [activityIcons]; the selected one is filled
/// with the activity colour.
class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String? selected;
  final Color color;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    Widget option(String? key, IconData icon, String label) {
      final isSelected = key == selected;
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: 'Icon $label',
          excludeSemantics: true,
          child: InkResponse(
            key: Key('icon-option-${key ?? 'none'}'),
            onTap: () => onSelected(key),
            radius: 24,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? color : scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? onColor : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        option(null, Icons.block, 'None'),
        for (final MapEntry(:key, :value) in activityIcons.entries)
          option(key, value, key[0].toUpperCase() + key.substring(1)),
      ],
    );
  }
}
