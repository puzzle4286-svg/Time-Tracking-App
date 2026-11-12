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
import 'entry_strip.dart';

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
          for (final a in activities.assignable)
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
      // Ask what fills any time the entry gives up.
      final fills = <FreedSide, int>{};
      final freed = await edits.freedRanges(
        entry.id,
        start: bounds.start,
        end: bounds.end,
      );
      for (final range in freed) {
        if (!context.mounted) return;
        final choice = await showDialog<int>(
          context: context,
          builder: (_) => _FillDialog(
            range: range,
            choices: [
              for (final a in activities.assignable)
                if (a.id != entry.activityId) a,
            ],
          ),
        );
        if (choice == null) return; // cancelled
        fills[range.side] = choice;
      }

      final effects = await edits.retime(
        entry.id,
        start: bounds.start,
        end: bounds.end,
        fills: fills,
        apply: false,
      );
      // Confirm whenever other entries lose time; then show the whole
      // picture, including the fills just chosen.
      final losesTime = effects.any(
        (e) => e.kind != EffectKind.added && e.kind != EffectKind.extended,
      );
      if (losesTime) {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _EffectsDialog(effects: effects, now: clock.now()),
        );
        if (ok != true) return;
      }
      await edits.retime(
        entry.id,
        start: bounds.start,
        end: bounds.end,
        fills: fills,
        apply: true,
      );
    });
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
    final result = await showDialog<({DeleteFill fill, int? activityId})>(
      context: context,
      builder: (_) => _DeleteDialog(
        entry: entry,
        activity: activity,
        options: options,
        now: clock.now(),
        choices: [
          for (final a in activities.assignable)
            if (a.id != entry.activityId) a,
        ],
      ),
    );
    if (result == null) return;
    await _run(
      () => edits.delete(entry.id, result.fill, activityId: result.activityId),
    );
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
  const _DeleteDialog({
    required this.entry,
    required this.activity,
    required this.options,
    required this.now,
    required this.choices,
  });

  final TimeEntry entry;
  final Activity activity;
  final DeleteOptions options;
  final DateTime now;

  /// Activities that can take the time when no neighbour is adjacent.
  final List<Activity> choices;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late DeleteFill _fill = widget.options.available.first;
  late int _activity = widget.choices.first.id;

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
      DeleteFill.activity => 'Give the time to:',
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
          EntryStripRow(
            color: Color(widget.activity.color),
            name: widget.activity.name,
            trailing: formatDurationPrecise(
              widget.entry.durationAt(widget.now),
            ),
          ),
          const SizedBox(height: 12),
          const Text('What should fill its time?'),
          const SizedBox(height: 8),
          // No neighbour touches it: pick the activity that takes over.
          if (widget.options.available.contains(DeleteFill.activity))
            _ActivityRadioList(
              choices: widget.choices,
              selected: _activity,
              onChanged: (id) => setState(() => _activity = id),
            )
          else
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
          onPressed: () =>
              Navigator.of(context).pop<({DeleteFill fill, int? activityId})>((
                fill: _fill,
                activityId: _fill == DeleteFill.activity ? _activity : null,
              )),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Confirmation of an edit's effects on other entries, grouped by what
/// happens to them and shown in the History entry style.
class _EffectsDialog extends StatelessWidget {
  const _EffectsDialog({required this.effects, required this.now});

  final List<EntryEffect> effects;
  final DateTime now;

  static const _order = [
    EffectKind.removed,
    EffectKind.shortened,
    EffectKind.splitAround,
    EffectKind.extended,
    EffectKind.added,
  ];

  static String _heading(EffectKind kind, int count) {
    final one = count == 1;
    final verb = switch (kind) {
      EffectKind.removed => 'removed',
      EffectKind.shortened => 'shortened',
      EffectKind.splitAround => 'split around the edited entry',
      EffectKind.extended => 'extended',
      EffectKind.added => 'added',
    };
    return one ? 'This entry will be $verb:' : 'These entries will be $verb:';
  }

  String _duration(EntryEffect e) {
    final before = formatDurationPrecise(e.entry.durationAt(now));
    return switch (e.kind) {
      EffectKind.shortened || EffectKind.extended =>
        '$before → ${formatDurationPrecise((e.newEnd ?? now).difference(e.newStart!))}',
      _ => before,
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('This changes other entries'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final kind in _order)
            if (effects.any((e) => e.kind == kind)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _heading(kind, effects.where((e) => e.kind == kind).length),
                  style: text.titleSmall,
                ),
              ),
              for (final e
                  in effects.where((e) => e.kind == kind).toList()
                    ..sort((a, b) => a.entry.start.compareTo(b.entry.start)))
                EntryStripRow(
                  color: Color(e.activity.color),
                  name: e.activity.name,
                  trailing: _duration(e),
                ),
            ],
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
    );
  }
}

/// Asks which activity takes over time an edited entry gives up. Time is
/// never left empty. The adjacent neighbour (if any) is marked and
/// preselected; Default comes last.
class _FillDialog extends StatefulWidget {
  const _FillDialog({required this.range, required this.choices});

  final FreedRange range;

  /// Activities that may fill it (never the edited entry's own activity).
  final List<Activity> choices;

  @override
  State<_FillDialog> createState() => _FillDialogState();
}

class _FillDialogState extends State<_FillDialog> {
  late int _selected = widget.range.neighbour?.id ?? widget.choices.first.id;

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    final where = range.side == FreedSide.start ? 'before' : 'after';
    final mark = range.side == FreedSide.start ? 'previous' : 'following';
    return AlertDialog(
      title: const Text('Fill the freed time'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This frees ${formatDurationPrecise(range.duration)} $where the '
            'entry. Which activity takes it over?',
          ),
          const SizedBox(height: 8),
          _ActivityRadioList(
            choices: widget.choices,
            selected: _selected,
            onChanged: (id) => setState(() => _selected = id),
            labelFor: (a) =>
                a.id == range.neighbour?.id ? '${a.name} ($mark)' : a.name,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

/// Radio list of activities with their colour.
class _ActivityRadioList extends StatelessWidget {
  const _ActivityRadioList({
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.labelFor,
  });

  final List<Activity> choices;
  final int? selected;
  final ValueChanged<int> onChanged;
  final String Function(Activity)? labelFor;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<int>(
      groupValue: selected,
      onChanged: (v) => onChanged(v!),
      child: Column(
        children: [
          for (final a in choices)
            RadioListTile<int>(
              value: a.id,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  CircleAvatar(radius: 7, backgroundColor: Color(a.color)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(labelFor?.call(a) ?? a.name)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
