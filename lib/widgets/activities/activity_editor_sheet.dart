import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/activity_colors.dart';
import '../../models/activity_icons.dart';
import '../../services/activities/activity_service.dart';

/// Values entered in the activity editor.
typedef ActivityDraft = ({
  String name,
  int color,
  String? icon,
  String description,
});

/// Bottom sheet for setting up an empty slot or editing an activity.
/// Returns the entered values, or null if cancelled. With [onDelete], a
/// "Delete activity" button closes the sheet and calls it; [onGoals] and
/// [onArrange] work the same way for "Goals" and "Rearrange grid".
Future<ActivityDraft?> showActivityEditor(
  BuildContext context, {
  required String title,
  required String initialName,
  required int initialColor,
  String? initialIcon,
  String? initialDescription,
  VoidCallback? onDelete,
  VoidCallback? onGoals,
  VoidCallback? onArrange,
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
      initialDescription: initialDescription,
      onDelete: onDelete,
      onGoals: onGoals,
      onArrange: onArrange,
    ),
  );
}

class _ActivityEditor extends StatefulWidget {
  const _ActivityEditor({
    required this.title,
    required this.initialName,
    required this.initialColor,
    required this.initialIcon,
    required this.initialDescription,
    required this.onDelete,
    required this.onGoals,
    required this.onArrange,
  });

  final String title;
  final String initialName;
  final int initialColor;
  final String? initialIcon;
  final String? initialDescription;
  final VoidCallback? onDelete;
  final VoidCallback? onGoals;
  final VoidCallback? onArrange;

  @override
  State<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<_ActivityEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _description = TextEditingController(
    text: widget.initialDescription ?? '',
  );
  late int _color = widget.initialColor;
  late String? _icon = widget.initialIcon;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop<ActivityDraft>((
      name: _name.text.trim(),
      color: _color,
      icon: _icon,
      description: _description.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        // Clear the keyboard, or else the system navigation bar (the app
        // draws edge to edge, so the sheet reaches under it).
        16 +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
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
                key: const Key('activity-name-field'),
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
              TextFormField(
                key: const Key('activity-description-field'),
                controller: _description,
                minLines: 2,
                maxLines: 5,
                maxLength: ActivityService.maxDescriptionLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'What it covers (optional)',
                  hintText: 'e.g. lectures, homework, reading for courses',
                  helperText: 'Swipe up on the grid to see all descriptions',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => ActivityService.validateDescription(v ?? ''),
              ),
              const SizedBox(height: 8),
              _ExpandableWrap(
                key: const Key('colour-section'),
                label: 'Colour',
                itemExtent: 40,
                selectedIndex: activityColors.indexOf(_color),
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
              _ExpandableWrap(
                key: const Key('icon-section'),
                label: 'Icon',
                itemExtent: 44,
                selectedIndex: _icon == null
                    ? 0
                    : activityIcons.keys.toList().indexOf(_icon!) + 1,
                children: _iconOptions(
                  context,
                  selected: _icon,
                  color: Color(_color),
                  onSelected: (key) => setState(() => _icon = key),
                ),
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
              if (widget.onArrange != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onArrange!();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Rearrange grid'),
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
List<Widget> _iconOptions(
  BuildContext context, {
  required String? selected,
  required Color color,
  required ValueChanged<String?> onSelected,
}) {
  final scheme = Theme.of(context).colorScheme;
  final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
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

  return [
    option(null, Icons.block, 'None'),
    for (final MapEntry(:key, :value) in activityIcons.entries)
      option(key, value, key[0].toUpperCase() + key.substring(1)),
  ];
}

/// A labelled set of choices that shows only its first row until the label
/// is tapped; tapping again closes it (D57). Closed by default. When the
/// selected choice is not in the first row, it takes that row's last place,
/// so the current choice is always visible.
class _ExpandableWrap extends StatefulWidget {
  const _ExpandableWrap({
    super.key,
    required this.label,
    required this.itemExtent,
    required this.selectedIndex,
    required this.children,
  });

  static const double spacing = 8;

  final String label;

  /// Width of every child.
  final double itemExtent;

  /// Index of the selected child, or -1 for none.
  final int selectedIndex;
  final List<Widget> children;

  @override
  State<_ExpandableWrap> createState() => _ExpandableWrapState();
}

class _ExpandableWrapState extends State<_ExpandableWrap> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            key: Key('${widget.label.toLowerCase()}-section-toggle'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(widget.label, style: theme.textTheme.labelLarge),
                  const SizedBox(width: 4),
                  // Points right when closed, down when open.
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = _ExpandableWrap.spacing;
            final perRow = math.max(
              1,
              ((constraints.maxWidth + spacing) / (widget.itemExtent + spacing))
                  .floor(),
            );
            final all = widget.children;
            final List<Widget> shown;
            if (_open || all.length <= perRow) {
              shown = all;
            } else if (widget.selectedIndex >= perRow) {
              shown = [...all.take(perRow - 1), all[widget.selectedIndex]];
            } else {
              shown = all.take(perRow).toList();
            }
            return AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: shown,
              ),
            );
          },
        ),
      ],
    );
  }
}
