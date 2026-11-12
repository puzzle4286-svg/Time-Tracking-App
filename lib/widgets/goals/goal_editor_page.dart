import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/goal.dart';
import '../../services/goals/goal_service.dart';
import '../../util/date_format.dart';
import 'goal_text.dart';

/// Result of the goal editor: a draft to save, or a delete request.
sealed class GoalEditResult {}

final class SaveGoal extends GoalEditResult {
  SaveGoal(this.draft);
  final GoalDraft draft;
}

final class DeleteGoal extends GoalEditResult {}

/// Full-screen form for creating ([existing] null) or editing a goal.
class GoalEditorPage extends StatefulWidget {
  const GoalEditorPage({
    super.key,
    required this.activityName,
    required this.now,
    this.existing,
  });

  final String activityName;
  final DateTime now;
  final Goal? existing;

  @override
  State<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends State<GoalEditorPage> {
  late final Goal? _g = widget.existing;
  late final _name = TextEditingController(text: _g?.name ?? '');
  late final _length = TextEditingController(text: '${_g?.length ?? 1}');
  late GoalUnit _unit = _g?.unit ?? GoalUnit.day;
  late GoalAnchor _anchor = _g?.anchor ?? _defaultAnchor(GoalUnit.day);
  late bool _hasMin = _g == null || _g.minimum != null;
  late bool _hasMax = _g?.maximum != null;
  late final _minH = TextEditingController(text: _hours(_g?.minimum, 1));
  late final _minM = TextEditingController(text: _minutes(_g?.minimum));
  late final _maxH = TextEditingController(text: _hours(_g?.maximum, 2));
  late final _maxM = TextEditingController(text: _minutes(_g?.maximum));
  late bool _enabled = _g?.enabled ?? true;
  String? _error;

  static String _hours(Duration? d, int fallback) =>
      '${d == null ? fallback : d.inHours}';
  static String _minutes(Duration? d) => '${d == null ? 0 : d.inMinutes % 60}';

  /// Sensible starts: today 00:00; weeks from this Monday; months from the 1st.
  GoalAnchor _defaultAnchor(GoalUnit unit) {
    final n = widget.now.toLocal();
    return switch (unit) {
      GoalUnit.week => GoalAnchor.fromLocal(
        DateTime(n.year, n.month, n.day - (n.weekday - 1)),
      ),
      GoalUnit.month => GoalAnchor(
        year: n.year,
        month: n.month,
        day: 1,
        minuteOfDay: 0,
      ),
      GoalUnit.hour => GoalAnchor.fromLocal(
        DateTime(n.year, n.month, n.day, n.hour),
      ),
      GoalUnit.day => GoalAnchor.fromLocal(DateTime(n.year, n.month, n.day)),
    };
  }

  @override
  void dispose() {
    for (final c in [_name, _length, _minH, _minM, _maxH, _maxM]) {
      c.dispose();
    }
    super.dispose();
  }

  Duration? _duration(
    bool on,
    TextEditingController h,
    TextEditingController m,
  ) => on
      ? Duration(
          hours: int.tryParse(h.text) ?? 0,
          minutes: int.tryParse(m.text) ?? 0,
        )
      : null;

  GoalDraft get _draft => GoalDraft(
    name: _name.text,
    unit: _unit,
    length: int.tryParse(_length.text) ?? 0,
    anchor: _anchor,
    minimum: _duration(_hasMin, _minH, _minM),
    maximum: _duration(_hasMax, _maxH, _maxM),
    enabled: _enabled,
  );

  void _save() {
    final draft = _draft;
    final error = draft.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop<GoalEditResult>(SaveGoal(draft));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text('Recorded time is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop<GoalEditResult>(DeleteGoal());
    }
  }

  Future<void> _pickDate() async {
    final current = _anchor.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(
      () => _anchor = GoalAnchor(
        year: picked.year,
        month: picked.month,
        day: picked.day,
        minuteOfDay: _anchor.minuteOfDay,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _anchor.hour, minute: _anchor.minute),
    );
    if (picked == null) return;
    setState(
      () => _anchor = GoalAnchor(
        year: _anchor.year,
        month: _anchor.month,
        day: _anchor.day,
        minuteOfDay: picked.hour * 60 + picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final length = int.tryParse(_length.text) ?? 1;
    final showsDate = _unit != GoalUnit.month;
    final dateLabel = switch (_unit) {
      GoalUnit.week =>
        length == 1 ? 'Starts on (weekday)' : 'First period starts on',
      _ => 'First period starts on',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_g == null ? 'New goal' : 'Edit goal'),
        actions: [
          if (_g != null)
            IconButton(
              tooltip: 'Delete goal',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.activityName, style: text.titleLarge),
          // Shown at the top so it is visible without scrolling.
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const Key('goal-error'),
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: GoalService.maxNameLength,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text('Period', style: text.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Every'),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const Key('goal-length'),
                  controller: _length,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<GoalUnit>(
                  key: const Key('goal-unit'),
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final u in GoalUnit.values)
                      DropdownMenuItem(
                        value: u,
                        child: Text(goalUnitLabel(u, length)),
                      ),
                  ],
                  onChanged: (u) => setState(() {
                    _unit = u!;
                    _anchor = _defaultAnchor(u);
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showsDate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dateLabel),
              subtitle: Text(formatShortDate(_anchor.toLocal())),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            )
          else
            Row(
              children: [
                const Expanded(child: Text('Starts on day of month')),
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<int>(
                    initialValue: _anchor.day,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (d) => setState(
                      () => _anchor = GoalAnchor(
                        year: _anchor.year,
                        month: _anchor.month,
                        day: d!,
                        minuteOfDay: _anchor.minuteOfDay,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('At'),
            subtitle: Text(goalTimeOfDay(_anchor)),
            trailing: const Icon(Icons.schedule),
            onTap: _pickTime,
          ),
          if (_unit == GoalUnit.month && _anchor.day > 28)
            Text(
              'In shorter months the period starts on the last day.',
              style: text.bodySmall,
            ),
          const Divider(height: 32),
          _TargetField(
            label: 'Minimum',
            enabled: _hasMin,
            hours: _minH,
            minutes: _minM,
            onToggle: (v) => setState(() => _hasMin = v),
          ),
          _TargetField(
            label: 'Maximum',
            enabled: _hasMax,
            hours: _maxH,
            minutes: _maxM,
            onToggle: (v) => setState(() => _hasMax = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
    );
  }
}

class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.label,
    required this.enabled,
    required this.hours,
    required this.minutes,
    required this.onToggle,
  });

  final String label;
  final bool enabled;
  final TextEditingController hours;
  final TextEditingController minutes;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    Widget number(TextEditingController c, String suffix) => SizedBox(
      width: 88,
      child: TextField(
        key: Key('$label-$suffix'),
        controller: c,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            key: Key('$label-toggle'),
            value: enabled,
            onChanged: (v) => onToggle(v!),
          ),
          Expanded(child: Text(label)),
          number(hours, 'h'),
          const SizedBox(width: 8),
          number(minutes, 'm'),
        ],
      ),
    );
  }
}
