import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../services/activities/activity_service.dart';
import '../../services/tracking/tracking_service.dart';

enum _HistoryOption { rename, move, unavailable }

/// Asks what should happen to [activity]'s history (and, if it is running,
/// which activity takes over), then deletes it.
Future<void> runDeleteActivityFlow(
  BuildContext context, {
  required Activity activity,
  required ActivityService activities,
  required TrackingService tracking,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final isActive = tracking.current.activity.id == activity.id;
  // Other grid activities, then Default last: there is always a successor.
  final others = activities.assignable
      .where((a) => a.id != activity.id)
      .toList();
  final count = await activities.entryCount(activity.id);
  if (!context.mounted) return;

  final result = await showDialog<({HistoryChoice? history, int? newActive})>(
    context: context,
    builder: (_) => _DeleteActivityDialog(
      activity: activity,
      others: others,
      isActive: isActive,
      entryCount: count,
    ),
  );
  if (result == null) return;
  try {
    await activities.delete(
      activity.id,
      history: result.history,
      newActiveId: result.newActive,
    );
    messenger.showSnackBar(
      SnackBar(content: Text('${activity.name} deleted.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
  }
}

class _DeleteActivityDialog extends StatefulWidget {
  const _DeleteActivityDialog({
    required this.activity,
    required this.others,
    required this.isActive,
    required this.entryCount,
  });

  final Activity activity;
  final List<Activity> others;
  final bool isActive;
  final int entryCount;

  @override
  State<_DeleteActivityDialog> createState() => _DeleteActivityDialogState();
}

class _DeleteActivityDialogState extends State<_DeleteActivityDialog> {
  late int? _newActive = widget.isActive ? widget.others.first.id : null;
  _HistoryOption _option = _HistoryOption.rename;
  late final _name = TextEditingController(
    text: '${widget.activity.name} (deleted)',
  );
  late int? _moveTo = widget.others.firstOrNull?.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _error => switch (_option) {
    _HistoryOption.rename => ActivityService.validateName(_name.text),
    _HistoryOption.move => _moveTo == null ? 'No other activity' : null,
    _HistoryOption.unavailable => null,
  };

  void _confirm() {
    final hasHistory = widget.entryCount > 0;
    if (hasHistory && _error != null) return;
    Navigator.of(context).pop<({HistoryChoice? history, int? newActive})>((
      history: !hasHistory
          ? null
          : switch (_option) {
              _HistoryOption.rename => KeepUnderName(_name.text.trim()),
              _HistoryOption.move => MoveToActivity(_moveTo!),
              _HistoryOption.unavailable => const MarkUnavailable(),
            },
      newActive: _newActive,
    ));
  }

  DropdownButtonFormField<int> _activityDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
    required String label,
    Key? key,
  }) => DropdownButtonFormField<int>(
    key: key,
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final a in widget.others)
        DropdownMenuItem(value: a.id, child: Text(a.name)),
    ],
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final text = Theme.of(context).textTheme;
    final hasHistory = widget.entryCount > 0;

    return AlertDialog(
      title: Text('Delete ${a.name}?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isActive) ...[
            Text('It is running now. Continue with:', style: text.bodyMedium),
            const SizedBox(height: 8),
            _activityDropdown(
              key: const Key('new-active'),
              value: _newActive,
              label: 'Runs from now on',
              onChanged: (v) => setState(() => _newActive = v),
            ),
            const SizedBox(height: 16),
          ],
          if (!hasHistory)
            Text('It has no recorded time.', style: text.bodyMedium)
          else ...[
            Text(
              'What should happen to its ${widget.entryCount} past '
              '${widget.entryCount == 1 ? 'entry' : 'entries'}? '
              'Their times are always kept.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<_HistoryOption>(
              groupValue: _option,
              onChanged: (v) => setState(() => _option = v!),
              child: Column(
                children: [
                  const RadioListTile(
                    value: _HistoryOption.rename,
                    title: Text('Keep them under a new name'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_option == _HistoryOption.rename)
                    TextField(
                      controller: _name,
                      maxLength: ActivityService.maxNameLength,
                      decoration: InputDecoration(
                        labelText: 'Name for past entries',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  RadioListTile(
                    value: _HistoryOption.move,
                    enabled: widget.others.isNotEmpty,
                    title: const Text('Move them to another activity'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_option == _HistoryOption.move)
                    _activityDropdown(
                      value: _moveTo,
                      label: 'Move to',
                      onChanged: (v) => setState(() => _moveTo = v),
                    ),
                  const RadioListTile(
                    value: _HistoryOption.unavailable,
                    title: Text('Mark them as "Unavailable"'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: hasHistory && _error != null ? null : _confirm,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
