import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/export/backup_files.dart';
import '../../services/export/backup_format.dart';
import '../../services/export/backup_service.dart';
import '../../util/clock.dart';
import '../../util/date_format.dart';

/// What Settings needs for export, backup and restore.
class DataActions {
  const DataActions({
    required this.backup,
    required this.files,
    required this.clock,
    required this.onRestored,
  });

  final BackupService backup;
  final BackupFiles files;
  final Clock clock;

  /// Reloads every service after the database was replaced.
  final Future<void> Function() onRestored;
}

/// Settings section: CSV export, JSON backup, restore.
class DataSection extends StatefulWidget {
  const DataSection({super.key, required this.actions});

  final DataActions actions;

  @override
  State<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<DataSection> {
  bool _busy = false;

  DataActions get _a => widget.actions;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save(
    String fileName,
    Future<Uint8List> Function() build,
    String mimeType,
    String what,
  ) async {
    try {
      final where = await _a.files.save(
        fileName: fileName,
        bytes: await build(),
        mimeType: mimeType,
      );
      if (where != null && mounted) _snack('$what saved to $where');
    } catch (e) {
      if (mounted) _snack('$what failed: $e');
    }
  }

  Future<void> _exportCsv() => _run(
    () => _save(
      csvFileName(_a.clock.now()),
      _a.backup.exportCsv,
      'text/csv',
      'CSV export',
    ),
  );

  Future<void> _createBackup() => _run(
    () => _save(
      backupFileName(_a.clock.now()),
      () async => (await _a.backup.createBackup()).encode(),
      'application/json',
      'Backup',
    ),
  );

  Future<void> _restore() => _run(() async {
    final BackupData data;
    try {
      final bytes = await _a.files.pickJson();
      if (bytes == null) return;
      data = BackupData.parse(bytes);
    } on BackupFormatException catch (e) {
      if (mounted) await _showError(e.message);
      return;
    } catch (e) {
      if (mounted) await _showError('The file could not be read ($e).');
      return;
    }
    if (!mounted || !await _confirmReplace(data)) return;
    try {
      await _a.backup.restore(data);
    } on BackupFormatException catch (e) {
      if (mounted) await _showError(e.message);
      return;
    }
    // Rebuilds the whole app, including this widget.
    await _a.onRestored();
  });

  Future<void> _showError(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cannot restore this file'),
      content: Text('$message\n\nYour current data was not changed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<bool> _confirmReplace(BackupData data) async {
    final now = _a.clock.now();
    final first = data.firstEntryStart;
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: Text(
          'Backup from ${formatDayLabel(data.createdAt, now)}, '
          '${formatTimeOfDay(data.createdAt)}\n'
          '${count(data.activityCount, 'activity', 'activities')}, '
          '${count(data.entryCount, 'time entry', 'time entries')}, '
          '${count(data.goalCount, 'goal', 'goals')}'
          '${first == null ? '' : '\nTracked since ${formatDayLabel(first, now)}'}'
          '\n\nAll current activities, history, goals and settings will be '
          'replaced. This cannot be undone. Make a backup first if you may '
          'need the current data.',
          key: const Key('restore-summary'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace all data'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export time entries (CSV)'),
          subtitle: const Text('For spreadsheets'),
          onTap: _exportCsv,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: const Icon(Icons.save_alt),
          title: const Text('Back up all data (JSON)'),
          subtitle: const Text('Activities, history, goals and settings'),
          onTap: _createBackup,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: const Icon(Icons.restore),
          title: const Text('Restore from backup'),
          subtitle: const Text('Replaces all current data'),
          onTap: _restore,
        ),
      ],
    );
  }
}
