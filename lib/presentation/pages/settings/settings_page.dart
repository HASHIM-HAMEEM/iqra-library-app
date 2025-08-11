import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/data/services/backup_service.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/ui/ui_state_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _biometricEnabled = false;
  bool _autoBackup = true;
  int _backupFrequencyDays = 7;
  int _sessionTimeout = 30;
  final _libraryNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dao = ref.read(appSettingsDaoProvider);
    final setup = ref.read(setupProvider.notifier);
    final themePref = await dao.getSettingValue('theme_mode');
    final autoBackup = await dao.getBoolSetting('auto_backup_enabled');
    final backupDays = await dao.getIntSetting('backup_frequency_days');
    final session = await dao.getIntSetting('session_timeout_minutes');
    final bio = await setup.isBiometricEnabled();
    final libName =
        await dao.getSettingValue('library_name') ??
        'Library Registration System';
    final adminEmail =
        await dao.getSettingValue('admin_email') ?? 'admin@library.com';
    if (!mounted) return;
    setState(() {
      _themeMode = switch (themePref) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _autoBackup = autoBackup ?? true;
      _backupFrequencyDays = backupDays ?? 7;
      _sessionTimeout = session ?? 30;
      _biometricEnabled = bio;
      _libraryNameCtrl.text = libName;
      _adminEmailCtrl.text = adminEmail;
      _loading = false;
    });
    // sync theme to UI provider
    ref.read(themeModeProvider.notifier).state = _themeMode;
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    ref.read(themeModeProvider.notifier).state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    // Persist user's explicit choice; appInit will honor it on next launch
    await ref.read(appSettingsDaoProvider).setStringSetting(
          'theme_mode',
          value,
          description: 'Theme mode: light, dark, or system',
        );
  }

  Future<void> _saveBiometric(bool enabled) async {
    setState(() => _biometricEnabled = enabled);
    await ref.read(setupProvider.notifier).setBiometricEnabled(enabled);
    await ref
        .read(appSettingsDaoProvider)
        .setBoolSetting(
          'biometric_auth_enabled',
          enabled,
          description: 'Biometric auth',
        );
  }

  Future<void> _saveSessionTimeout(int minutes) async {
    setState(() => _sessionTimeout = minutes);
    await ref
        .read(appSettingsDaoProvider)
        .setIntSetting(
          'session_timeout_minutes',
          minutes,
          description: 'Session timeout',
        );
    await ref.read(authProvider.notifier).refreshSessionTimeout();
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildModernHeader(theme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  _buildSectionHeader('Profile', theme),
                  _buildCard(
                    theme,
                    child: Column(
                      children: [
                        _buildTextField(
                          label: 'Library Name',
                          controller: _libraryNameCtrl,
                          onChanged: (v) => ref
                              .read(appSettingsDaoProvider)
                              .setStringSetting('library_name', v),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Admin Email',
                          controller: _adminEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (v) => ref
                              .read(appSettingsDaoProvider)
                              .setStringSetting('admin_email', v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Appearance Section
                  _buildSectionHeader('Appearance', theme),
                  _buildCard(
                    theme,
                    child: _buildListTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: switch (_themeMode) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        _ => 'System Default',
                      },
                      onTap: _showThemeSheet,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Security Section
                  _buildSectionHeader('Security', theme),
                  _buildCard(
                    theme,
                    child: Column(
                      children: [
                        _buildSwitchListTile(
                          icon: Icons.fingerprint_outlined,
                          title: 'Biometric Authentication',
                          subtitle: 'Use Face ID/Touch ID to sign in',
                          value: _biometricEnabled,
                          onChanged: _saveBiometric,
                        ),
                        _buildDivider(theme),
                        _buildListTile(
                          icon: Icons.timer_outlined,
                          title: 'Session Timeout',
                          subtitle: '$_sessionTimeout minutes',
                          onTap: _showSessionSheet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Backup & Storage Section
                  _buildSectionHeader('Backup & Storage', theme),
                  _buildCard(
                    theme,
                    child: Column(
                      children: [
                        _buildSwitchListTile(
                          icon: Icons.cloud_outlined,
                          title: 'Automatic Backups',
                          subtitle: 'Periodically back up your data',
                          value: _autoBackup,
                          onChanged: _saveAutoBackup,
                        ),
                        _buildDivider(theme),
                        _buildListTile(
                          icon: Icons.schedule_outlined,
                          title: 'Backup Frequency',
                          subtitle: _frequencyLabel(_backupFrequencyDays),
                          onTap: _showBackupSheet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Cards
                  _buildActionCard(
                    icon: Icons.backup_outlined,
                    title: 'Export Full Backup',
                    subtitle: 'All data and media into a ZIP',
                    onTap: _showExportOptions,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.settings_backup_restore_outlined,
                    title: 'Import Backup',
                    subtitle: 'Restore from an exported ZIP',
                    onTap: _showImportBackupPicker,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.restart_alt_outlined,
                    title: 'Reset to Defaults',
                    subtitle: 'Restore all settings to default values',
                    destructive: true,
                    onTap: () async {
                      await ref.read(appSettingsDaoProvider).resetToDefaults();
                      await _loadSettings();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings reset to defaults'),
                        ),
                      );
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Center(child: _buildFooter(theme)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage app preferences and configurations',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.outline,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      color: theme.colorScheme.outline.withValues(alpha: 0.3),
      height: 32,
      thickness: 0.5,
      indent: 60,
      endIndent: 0,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    bool destructive = false,
  }) {
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    final bgColor = destructive
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
        : theme.colorScheme.primary.withValues(alpha: 0.05);

    return Card(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor:
          theme.colorScheme.onSurface.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: destructive
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final subtle = theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'scnz.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: subtle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'hashimdar141@yahoo.com',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: subtle,
          ),
        ),
      ],
    );
  }

  String _frequencyLabel(int days) {
    switch (days) {
      case 1:
        return 'Daily';
      case 7:
        return 'Weekly';
      case 14:
        return 'Every 2 weeks';
      case 30:
        return 'Monthly';
      default:
        return 'Every $days days';
    }
  }

  void _showThemeSheet() {
    final theme = Theme.of(context);
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        Widget option(String label, ThemeMode value) {
          final selected = _themeMode == value;
          return ListTile(
            onTap: () {
              Navigator.of(ctx).pop();
              _saveTheme(value);
            },
            title: Text(label, style: theme.textTheme.bodyLarge),
            trailing: selected
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : const SizedBox.shrink(),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Choose theme',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            option('System Default', ThemeMode.system),
            option('Light', ThemeMode.light),
            option('Dark', ThemeMode.dark),
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

  Future<void> _showImportBackupPicker() async {
    final docs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docs.path, 'backups'));
    final hasDir = await backupsDir.exists();
    final entries = hasDir
        ? backupsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.zip'))
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

  Future<void> _importCsv(String path) async {
    try {
      final backup = ref.read(backupServiceProvider);
      await backup.importCsv(path, onProgress: (_) {});
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

  void _showSessionSheet() {
    final theme = Theme.of(context);
    const options = [15, 30, 60];
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Session timeout',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map((minutes) {
              final selected = _sessionTimeout == minutes;
              return ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _saveSessionTimeout(minutes);
                },
                title: Text(
                  '$minutes minutes',
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

  void _showBackupSheet() {
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
}
