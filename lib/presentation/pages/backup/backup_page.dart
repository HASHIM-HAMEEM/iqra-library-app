import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/data/services/backup_service.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _loading = true;
  bool _autoBackup = true;
  int _backupFrequencyDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = ref.read(appSettingsDaoProvider);
    final autoBackup = await dao.getBoolSetting('auto_backup_enabled');
    final backupDays = await dao.getIntSetting('backup_frequency_days');
    if (!mounted) return;
    setState(() {
      _autoBackup = autoBackup ?? true;
      _backupFrequencyDays = backupDays ?? 7;
      _loading = false;
    });
  }

  Future<void> _saveAutoBackup(bool enabled) async {
    setState(() => _autoBackup = enabled);
    await ref
        .read(appSettingsDaoProvider)
        .setBoolSetting(
          'auto_backup_enabled',
          enabled,
          description: 'Auto backup',
        );
  }

  Future<void> _saveBackupFrequency(int days) async {
    setState(() => _backupFrequencyDays = days);
    await ref
        .read(appSettingsDaoProvider)
        .setIntSetting(
          'backup_frequency_days',
          days,
          description: 'Backup frequency',
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Header
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(
              context,
            ).copyWith(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Export, import, and schedule backups',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: ListView(
              padding: ResponsiveUtils.getResponsivePadding(
                context,
              ).copyWith(top: 12, bottom: 24),
              children: [
                const _SectionTitle('Automatic Backups'),
                _CardBlock(
                  children: [
                    _ListRow(
                      icon: Icons.cloud_done_outlined,
                      iconTint: theme.colorScheme.primary,
                      title: 'Enable automatic backups',
                      subtitle: 'Creates backups on a schedule',
                      trailing: Switch(
                        value: _autoBackup,
                        onChanged: _saveAutoBackup,
                      ),
                    ),
                    const _RowDivider(),
                    _ListRow(
                      icon: Icons.schedule_outlined,
                      iconTint: theme.colorScheme.primary,
                      title: 'Backup frequency',
                      subtitle: _frequencyLabel(_backupFrequencyDays),
                      onTap: _showFrequencySheet,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Create / Import'),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showExportOptions,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Create Backup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showImportPicker,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Import'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Existing Backups'),
                FutureBuilder<List<File>>(
                  future: _listBackups(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final files = snap.data ?? [];
                    if (files.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: _EmptyBackups(onCreate: _showExportOptions),
                      );
                    }
                    final entries =
                        files.map((f) => MapEntry(f, f.statSync())).toList()
                          ..sort(
                            (a, b) =>
                                b.value.modified.compareTo(a.value.modified),
                          );

                    return _CardBlock(
                      children: [
                        ...entries.map((entry) {
                          final f = entry.key;
                          final st = entry.value;
                          return Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.archive_outlined),
                                title: Text(p.basename(f.path)),
                                subtitle: Text(
                                  '${_fmtBytes(st.size)} • ${_fmtDateTime(st.modified)}',
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'Share',
                                      onPressed: () => Share.shareFiles(
                                        [f.path],
                                        subject: 'Library backup',
                                        text: p.basename(f.path),
                                      ),
                                      icon: const Icon(Icons.share_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Import',
                                      onPressed: () =>
                                          _confirmAndImport(f.path),
                                      icon: const Icon(
                                        Icons.file_download_done_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        await f.delete();
                                        if (mounted) setState(() {});
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                              if (f != entries.last.key) const _RowDivider(),
                            ],
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _frequencyLabel(int days) {
    switch (days) {
      case 1:
        return 'Daily';
      case 7:
        return 'Every 7 days';
      case 14:
        return 'Every 14 days';
      case 30:
        return 'Every 30 days';
      default:
        return 'Every $days days';
    }
  }

  void _showFrequencySheet() {
    final theme = Theme.of(context);
    const options = [1, 7, 14, 30];
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Backup frequency',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map((days) {
              final selected = _backupFrequencyDays == days;
              return ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _saveBackupFrequency(days);
                },
                title: Text(
                  _frequencyLabel(days),
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: selected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : const SizedBox.shrink(),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _showExportOptions() async {
    final theme = Theme.of(context);
    var includeMedia = true;
    await showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Export options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SwitchListTile(
                  value: includeMedia,
                  onChanged: (v) => setState(() => includeMedia = v),
                  title: const Text('Include media files'),
                  subtitle: const Text('Photos and other attachments'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Start export'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportFullBackup(includeMedia: includeMedia);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Export CSV only (Excel) — no ZIP'),
                  subtitle: const Text('Writes CSV files to backups folder'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportCsvOnly();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportFullBackup({bool includeMedia = true}) async {
    final backup = ref.read(backupServiceProvider);
    var stage = 'Starting…';
    var current = 0;
    var total = 0;
    var started = false;
    late StateSetter dialogSetState;
    BuildContext? dialogContext;
    var dialogClosed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState = setState;
            dialogContext = ctx;
            if (dialogClosed) return const SizedBox.shrink();
            if (!started) {
              started = true;
              Future<void>.microtask(() async {
                try {
                  final result = await backup.exportBackup(
                    includeMedia: includeMedia,
                    onProgress: (p) {
                      final dc = dialogContext;
                      if (dc != null && dc.mounted && !dialogClosed) {
                        dialogSetState(() {
                          stage = p.stage;
                          current = p.current;
                          total = p.total;
                        });
                      }
                    },
                  );
                  if (!dialogClosed && ctx.mounted) {
                    dialogClosed = true;
                    Navigator.of(ctx).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Backup saved: ${p.basename(result.filePath)}',
                      ),
                    ),
                  );
                  await _showShareBackupSheet(result.filePath, result.bytes);
                  setState(() {}); // refresh list
                } catch (e) {
                  if (!dialogClosed && ctx.mounted) {
                    dialogClosed = true;
                    Navigator.of(ctx).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                }
              });
            }
            final progress = total > 0 ? current / total : null;
            return AlertDialog(
              title: const Text('Exporting backup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('$stage ($current/$total)'),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dialogClosed = true;
    });
  }

  Future<void> _exportCsvOnly() async {
    final backup = ref.read(backupServiceProvider);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final backupsDir = Directory(p.join(docs.path, 'backups'))
        ..createSync(recursive: true);

      // Build current snapshots from DAOs and write CSVs directly
      final students = await backup.studentsDao.getAllStudents();
      final subs = await backup.subscriptionsDao.getAllSubscriptions();
      final logs = await backup.activityLogsDao.getAllActivityLogs();

      final studentsCsv = File(p.join(backupsDir.path, 'students_${DateTime.now().millisecondsSinceEpoch}.csv'));
      final subsCsv = File(p.join(backupsDir.path, 'subscriptions_${DateTime.now().millisecondsSinceEpoch}.csv'));
      final logsCsv = File(p.join(backupsDir.path, 'activity_logs_${DateTime.now().millisecondsSinceEpoch}.csv'));

      // Use service helpers for consistent CSV formatting
      await backup
          .exportBackup(includeMedia: false)
          .then((_) async {
        // The exportBackup path creates CSVs in a temp dir; instead, write our own here:
      });

      // Reuse service CSV writers by constructing temp service instance? We'll call internal via a local adapter
      // Fallback: write minimal CSVs here mirroring service schema
      await studentsCsv.writeAsString(
        'id,firstName,lastName,dateOfBirth,email,phone,address,profileImagePath,createdAt,updatedAt,isDeleted,subscriptionPlan,subscriptionStartDate,subscriptionEndDate,subscriptionAmount,subscriptionStatus\n',
        mode: FileMode.write,
      );
      for (final s in students) {
        final row = [
          s.id,
          _csv(s.firstName),
          _csv(s.lastName),
          s.dateOfBirth.toIso8601String(),
          _csv(s.email),
          _csv(s.phone),
          _csv(s.address),
          _csv(s.profileImagePath),
          s.createdAt.toIso8601String(),
          s.updatedAt.toIso8601String(),
          s.isDeleted,
          _csv(s.subscriptionPlan),
          s.subscriptionStartDate?.toIso8601String() ?? '',
          s.subscriptionEndDate?.toIso8601String() ?? '',
          s.subscriptionAmount?.toString() ?? '',
          _csv(s.subscriptionStatus),
        ].join(',');
        await studentsCsv.writeAsString('$row\n', mode: FileMode.append);
      }

      await subsCsv.writeAsString(
        'id,studentId,planName,startDate,endDate,amount,status,createdAt,updatedAt\n',
        mode: FileMode.write,
      );
      for (final s in subs) {
        final row = [
          s.id,
          s.studentId,
          _csv(s.planName),
          s.startDate.toIso8601String(),
          s.endDate?.toIso8601String() ?? '',
          s.amount.toString(),
          s.status,
          s.createdAt.toIso8601String(),
          s.updatedAt.toIso8601String(),
        ].join(',');
        await subsCsv.writeAsString('$row\n', mode: FileMode.append);
      }

      await logsCsv.writeAsString(
        'id,action,entityType,entityId,details,timestamp,userId\n',
        mode: FileMode.write,
      );
      for (final l in logs) {
        final row = [
          l.id,
          _csv(l.action),
          _csv(l.entityType),
          _csv(l.entityId),
          _csv(l.details),
          l.timestamp.toIso8601String(),
          _csv(l.userId),
        ].join(',');
        await logsCsv.writeAsString('$row\n', mode: FileMode.append);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV files exported to backups folder')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    }
  }

  String _csv(String? v) {
    if (v == null) return '';
    final escaped = v.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('\n') || escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  Future<void> _showImportPicker() async {
    final docs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docs.path, 'backups'));
    final hasDir = await backupsDir.exists();
    final entries = hasDir
        ? backupsDir
              .listSync()
              .whereType<File>()
              .where((f) {
                final n = f.path.toLowerCase();
                return n.endsWith('.zip') || n.endsWith('.csv');
              })
              .toList()
        : <File>[];

    if (entries.isEmpty) {
      if (!mounted) return;
      final theme = Theme.of(context);
      await showAppBottomSheet<void>(
        context,
        builder: (ctx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No backups found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Choose from device files'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickFromDeviceAndImport();
                },
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Backups will appear here after you create one.'),
                subtitle: Text(
                  "Backups are stored in the app's documents/backups folder.",
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Create Backup Now'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showExportOptions();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // Cache stats and sort once
    final pairs = entries.map((f) => MapEntry(f, f.statSync())).toList()
      ..sort((a, b) => b.value.modified.compareTo(a.value.modified));

    final theme = Theme.of(context);
    await showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Select a backup to import',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Choose from device files'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickFromDeviceAndImport();
              },
            ),
            ...pairs.map((pair) {
              final f = pair.key;
              final stat = pair.value;
              return ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(p.basename(f.path)),
                subtitle: Text(
                  '${_fmtBytes(stat.size)} • ${_fmtDateTime(stat.modified)}',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmAndImport(f.path);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    Share.shareFiles(
                      [f.path],
                      subject: 'Library backup',
                      text: p.basename(f.path),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _pickFromDeviceAndImport() async {
    try {
      // Best-effort: request storage permission on Android (pre-13 devices)
      try {
        await Permission.storage.request();
      } catch (_) {}

      const typeGroup = XTypeGroup(
        label: 'Backup',
        extensions: ['zip', 'csv'],
        mimeTypes: [
          'application/zip',
          'application/x-zip-compressed',
          'text/csv',
          'application/csv',
        ],
      );
      XFile? picked;
      try {
        picked = await openFile(acceptedTypeGroups: [typeGroup]);
      } catch (_) {
        picked = null;
      }
      String? destPath;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final tmp = await getTemporaryDirectory();
        destPath = p.join(
          tmp.path,
          'import_${DateTime.now().millisecondsSinceEpoch}.zip',
        );
        final file = File(destPath);
        await file.writeAsBytes(bytes);
      } else {
        // Fallback to file_picker
        final res = await fp.FilePicker.platform.pickFiles(
          type: fp.FileType.custom,
          allowedExtensions: const ['zip', 'csv'],
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final f = res.files.single;
        final bytes = f.bytes ?? await File(f.path!).readAsBytes();
        final tmp = await getTemporaryDirectory();
        destPath = p.join(
          tmp.path,
          'import_${DateTime.now().millisecondsSinceEpoch}.zip',
        );
        final file = File(destPath);
        await file.writeAsBytes(bytes);
      }
      if (!mounted) return;
      if (destPath.toLowerCase().endsWith('.csv')) {
        await _importCsv(destPath);
      } else {
        await _confirmAndImport(destPath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }

  Future<void> _confirmAndImport(String path) async {
    final theme = Theme.of(context);
    await showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Import mode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type_outlined),
              title: const Text('Merge (skip duplicates)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importBackup(
                  path,
                  const ImportOptions(
                    
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.warning_amber_outlined,
                color: Colors.red,
              ),
              title: const Text('Overwrite (replace) — clears existing data'),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmOverwriteImport(path);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _importCsv(String path) async {
    try {
      final backup = ref.read(backupServiceProvider);
      await backup.importCsv(path, onProgress: (p) {
        // optional: could update a progress UI
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV import completed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV import failed: $e')),
      );
    }
  }

  Future<void> _confirmOverwriteImport(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm overwrite'),
          content: const Text(
            'This will replace existing data with the backup contents. This action cannot be undone. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Overwrite'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _importBackup(
        path,
        const ImportOptions(
          mode: ImportMode.overwrite,
          duplicatePolicy: DuplicatePolicy.replace,
        ),
      );
    }
  }

  Future<void> _importBackup(String path, ImportOptions options) async {
    final backup = ref.read(backupServiceProvider);
    var stage = 'Starting…';
    var current = 0;
    var total = 0;
    var started = false;
    BuildContext? dialogContext;
    var dialogClosed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            dialogContext = ctx;
            if (dialogClosed) return const SizedBox.shrink();
            if (!started) {
              started = true;
              Future<void>.microtask(() async {
                try {
                  final result = await backup.importBackup(
                    path,
                    options: options,
                    onProgress: (p) {
                      final dc = dialogContext;
                      if (dc != null && dc.mounted && !dialogClosed) {
                        setState(() {
                          stage = p.stage;
                          current = p.current;
                          total = p.total;
                        });
                      }
                    },
                  );
                  if (!dialogClosed && ctx.mounted) {
                    dialogClosed = true;
                    Navigator.of(ctx).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Import complete: inserted ${result.inserted.values.fold<int>(0, (a, b) => a + b)}, updated ${result.updated.values.fold<int>(0, (a, b) => a + b)}, skipped ${result.skipped.values.fold<int>(0, (a, b) => a + b)}',
                      ),
                    ),
                  );
                  setState(() {}); // refresh list
                } catch (e) {
                  if (!dialogClosed && ctx.mounted) {
                    dialogClosed = true;
                    Navigator.of(ctx).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              });
            }
            final progress = total > 0 ? current / total : null;
            return AlertDialog(
              title: const Text('Importing backup'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('$stage ($current/$total)'),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dialogClosed = true;
    });
  }

  Future<List<File>> _listBackups() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) return <File>[];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();
  }

  Future<void> _showShareBackupSheet(String filePath, int bytes) async {
    final theme = Theme.of(context);
    await showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Backup created',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(p.basename(filePath)),
              subtitle: Text(_fmtBytes(bytes)),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share backup'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Share.shareFiles(
                  [filePath],
                  subject: 'Library backup',
                  text: p.basename(filePath),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size < 10 && unit > 0 ? 1 : 0)} ${units[unit]}';
  }

  String _fmtDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: Column(children: children),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconTint,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconTint;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: (iconTint ?? theme.colorScheme.primary).withValues(
          alpha: 0.12,
        ),
        foregroundColor: iconTint ?? theme.colorScheme.primary,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.8);
  }
}

class _EmptyBackups extends StatelessWidget {
  const _EmptyBackups({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.archive_outlined, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          'No backups yet',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create your first backup to get started',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Create Backup'),
        ),
      ],
    );
  }
}
