import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/time_entry.dart';
import '../../services/activities/activity_service.dart';
import '../../services/history/entry_edit_service.dart';
import '../../services/history/history_service.dart';
import '../../util/clock.dart';
import '../../util/date_format.dart';
import '../../util/duration_format.dart';
import '../common/date_time_picker.dart';

/// Opens the actions for one history entry: change activity, change start /
/// end, delete. Every change that affects other entries is confirmed
/// first.
Future<void> showEntryEditor(
  BuildContext context, {
  required DayEntry item,
  required EntryEditService edits,
  required ActivityService activities,
  required Clock clock,
}) async {
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true, // size to content; scrolls on short screens
    builder: (context) => _EntrySheet(item: item, now: clock.now()),
  );
  if (action == null || !context.mounted) return;
  final flow = _EntryFlow(
    context,
    item.entry,
    item.activity,
    edits,
    activities,
    clock,
  );
  await switch (action) {
    _Action.activity => flow.changeActivity(),
    _Action.times => flow.changeTimes(),
    _Action.delete => flow.delete(),
  };
}

enum _Action { activity, times, delete }

String _span(TimeEntry e) =>
    '${formatMoment(e.start)} – ${e.end == null ? 'now' : formatTimeOfDay(e.end!)}';

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.item, required this.now});

  final DayEntry item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = item.entry;
    ListTile tile(_Action a, IconData icon, String label) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(a),
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 8,
                backgroundColor: Color(item.activity.color),
              ),
              title: Text(item.activity.name, style: text.titleLarge),
              subtitle: Text(
                '${_span(e)} · ${formatEntryDuration(e.durationAt(now))}',
              ),
            ),
            const Divider(),
            tile(_Action.activity, Icons.swap_horiz, 'Change activity'),
            tile(_Action.times, Icons.schedule, 'Change start / end'),
            tile(_Action.delete, Icons.delete_outline, 'Delete'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EntryFlow {
  _EntryFlow(
    this.context,
    this.entry,
    this.activity,
    this.edits,
    this.activities,
    this.clock,
  );

  final BuildContext context;
  final TimeEntry entry;
  final Activity activity;
  final EntryEditService edits;
  final ActivityService activities;
  final Clock clock;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on EditException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> changeActivity() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change activity'),
        children: [
          for (final a in activities.live)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(a.id),
              child: Row(
                children: [
                  CircleAvatar(radius: 8, backgroundColor: Color(a.color)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name)),
                  if (a.id == entry.activityId) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == entry.activityId) return;
    await _run(() => edits.changeActivity(entry.id, picked));
  }

  Future<void> changeTimes() async {
    final bounds = await showDialog<({DateTime start, DateTime? end})>(
      context: context,
      builder: (_) => _TimesDialog(entry: entry, clock: clock),
    );
    if (bounds == null || !context.mounted) return;
    await _run(() async {
      final effects = await edits.retime(
        entry.id,
        start: bounds.start,
        end: bounds.end,
        apply: false,
      );
      if (effects.isNotEmpty) {
        if (!context.mounted) return;
        final ok = await _confirmEffects(effects);
        if (ok != true) return;
      }
      await edits.retime(
        entry.id,
        start: bounds.start,
        end: bounds.end,
        apply: true,
      );
    });
  }

  Future<bool?> _confirmEffects(List<EntryEffect> effects) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('This changes other entries'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in effects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• ${_describe(e)}'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    ),
  );

  static String _describe(EntryEffect e) {
    final name = e.activity.name;
    final old = _span(e.entry);
    String fresh() =>
        '${formatTimeOfDay(e.newStart!)} – '
        '${e.newEnd == null ? 'now' : formatTimeOfDay(e.newEnd!)}';
    return switch (e.kind) {
      EffectKind.shortened => '$name $old will be shortened to ${fresh()}',
      EffectKind.extended => '$name $old will be extended to ${fresh()}',
      EffectKind.removed => '$name $old will be removed',
      EffectKind.splitAround => '$name $old will be split around this entry',
    };
  }

  Future<void> delete() async {
    final options = await edits.deleteOptions(entry.id);
    if (!context.mounted) return;
    if (options.available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is the only entry and it is running, so it cannot be deleted.',
          ),
        ),
      );
      return;
    }
    final fill = await showDialog<DeleteFill>(
      context: context,
      builder: (_) => _DeleteDialog(entry: entry, options: options),
    );
    if (fill == null) return;
    await _run(() => edits.delete(entry.id, fill));
  }
}

class _TimesDialog extends StatefulWidget {
  const _TimesDialog({required this.entry, required this.clock});

  final TimeEntry entry;
  final Clock clock;

  @override
  State<_TimesDialog> createState() => _TimesDialogState();
}

class _TimesDialogState extends State<_TimesDialog> {
  late DateTime _start = widget.entry.start;
  late DateTime? _end = widget.entry.end;

  Future<void> _pick(bool start) async {
    final now = widget.clock.now();
    final current = start ? _start : _end!;
    final picked = await pickDateTime(
      context,
      current,
      first: DateTime(2000),
      last: now,
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.entry.isOpen;
    return AlertDialog(
      title: const Text('Change start / end'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('pick-start'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(formatMoment(_start)),
            trailing: const Icon(Icons.edit),
            onTap: () => _pick(true),
          ),
          ListTile(
            key: const Key('pick-end'),
            contentPadding: EdgeInsets.zero,
            title: const Text('End'),
            subtitle: Text(
              running ? 'Running (ends when you switch)' : formatMoment(_end!),
            ),
            trailing: running ? null : const Icon(Icons.edit),
            onTap: running ? null : () => _pick(false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop<({DateTime start, DateTime? end})>((start: _start, end: _end)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.entry, required this.options});

  final TimeEntry entry;
  final DeleteOptions options;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late DeleteFill _fill = widget.options.available.first;

  String _label(DeleteFill f) {
    final prev = widget.options.previous?.activity.name;
    final next = widget.options.following?.activity.name;
    final sameBoth =
        widget.options.following?.activity.id ==
        widget.options.previous?.activity.id;
    return switch (f) {
      DeleteFill.previous =>
        widget.entry.isOpen
            ? 'Resume the previous activity ($prev)'
            : sameBoth
            ? 'Fill with $prev'
            : 'Fill with the previous activity ($prev)',
      DeleteFill.following => 'Fill with the following activity ($next)',
      DeleteFill.split => 'Split evenly between $prev and $next',
      DeleteFill.leaveEmpty => 'Leave the time empty',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete entry?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should fill ${_span(widget.entry)}?'),
          const SizedBox(height: 8),
          RadioGroup<DeleteFill>(
            groupValue: _fill,
            onChanged: (v) => setState(() => _fill = v!),
            child: Column(
              children: [
                for (final f in widget.options.available)
                  RadioListTile(
                    value: f,
                    title: Text(_label(f)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
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
          onPressed: () => Navigator.of(context).pop(_fill),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
