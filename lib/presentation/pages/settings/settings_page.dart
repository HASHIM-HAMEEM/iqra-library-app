import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/ui/ui_state_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _biometricEnabled = false;

  int _sessionTimeout = 30;
  final _libraryNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    // Navigate to auth screen
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  Future<void> _loadSettings() async {
    final dao = ref.read(appSettingsDaoProvider);
    final setup = ref.read(setupProvider.notifier);
    final themePref = await dao.getStringSetting('theme_mode');

    final session = await dao.getIntSetting('session_timeout_minutes');
    final bio = await setup.isBiometricEnabled();
    final libName = await dao.getStringSetting('library_name');
    final adminEmail = await dao.getStringSetting('admin_email');
    if (!mounted) return;
    setState(() {
      _themeMode = switch (themePref) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      _sessionTimeout = session ?? 30;
      _biometricEnabled = bio;
      _libraryNameCtrl.text = libName ?? _libraryNameCtrl.text;
      _adminEmailCtrl.text = adminEmail ?? _adminEmailCtrl.text;
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
    await ref.read(setupProvider.notifier).setBiometricEnabled(enabled: enabled);
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
                           onChanged: (v) async {
                             await ref.read(appSettingsDaoProvider).setStringSetting('library_name', v);
                           },
                        ),
                        const SizedBox(height: 16),
                         _buildTextField(
                          label: 'Admin Email',
                          controller: _adminEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                           onChanged: (v) async {
                             await ref.read(appSettingsDaoProvider).setStringSetting('admin_email', v);
                           },
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
                          subtitle: _formatTimeoutLabel(_sessionTimeout),
                          onTap: _showSessionSheet,
                        ),
                         _buildDivider(theme),
                         ListTile(
                           contentPadding: EdgeInsets.zero,
                           leading: Container(
                             width: 44,
                             height: 44,
                             decoration: BoxDecoration(
                               color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 22),
                           ),
                           title: Text(
                             'Sign out',
                             style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                           ),
                           subtitle: Text(
                             'Return to the login screen',
                             style: theme.textTheme.bodyMedium?.copyWith(
                               color: theme.colorScheme.onSurfaceVariant,
                             ),
                           ),
                           onTap: _logout,
                         ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),



                  _buildActionCard(
                    icon: Icons.restart_alt_outlined,
                    title: 'Reset to Defaults',
                    subtitle: 'Restore all settings to default values',
                    destructive: true,
                    onTap: () async {
                      await ref.read(appSettingsDaoProvider).resetToDefaults();
                      await _loadSettings();
                      if (!mounted) return;
                      CustomNotification.show(
                        context,
                        message: 'Settings reset to defaults',
                        type: NotificationType.success,
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







  String _formatTimeoutLabel(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$minutes minutes';
  }

  void _showSessionSheet() {
    final theme = Theme.of(context);
    const options = [30, 60, 120];
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
                  _formatTimeoutLabel(minutes),
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
