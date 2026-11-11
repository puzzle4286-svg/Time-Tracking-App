import 'package:flutter/material.dart';

import '../../models/activity_colors.dart';
import '../../services/activities/activity_service.dart';

/// Values entered in the activity editor.
typedef ActivityDraft = ({String name, int color});

/// Bottom sheet for setting up an empty slot or editing an activity.
/// Returns the entered values, or null if cancelled.
Future<ActivityDraft?> showActivityEditor(
  BuildContext context, {
  required String title,
  required String initialName,
  required int initialColor,
}) {
  return showModalBottomSheet<ActivityDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ActivityEditor(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
    ),
  );
}

class _ActivityEditor extends StatefulWidget {
  const _ActivityEditor({
    required this.title,
    required this.initialName,
    required this.initialColor,
  });

  final String title;
  final String initialName;
  final int initialColor;

  @override
  State<_ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<_ActivityEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop<ActivityDraft>((name: _name.text.trim(), color: _color));
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
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
