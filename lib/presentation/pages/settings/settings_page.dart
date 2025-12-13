import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/ui/ui_state_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';
import 'package:library_registration_app/presentation/widgets/common/modern_text_field.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _biometricEnabled = false;

  // Session timeout removed - user stays logged in indefinitely
  final _libraryNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _libraryNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  Future<void> _loadSettings() async {
    final dao = ref.read(appSettingsDaoProvider);
    final setup = ref.read(setupProvider.notifier);

    // Read theme from provider (already loaded on app init) - don't read from DB again
    final currentTheme = ref.read(themeModeProvider);

    // Session timeout removed - no longer loading it
    final bio = await setup.isBiometricEnabled();
    final libName = await dao.getStringSetting('library_name');
    final adminEmail = await dao.getStringSetting('admin_email');
    if (!mounted) return;
    setState(() {
      _themeMode = currentTheme; // Use the already-loaded theme
      _biometricEnabled = bio;
      _libraryNameCtrl.text = libName ?? '';
      _adminEmailCtrl.text = adminEmail ?? '';
      _loading = false;
    });
    // Don't update themeModeProvider here - it's already set correctly
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    ref.read(themeModeProvider.notifier).state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await ref
        .read(appSettingsDaoProvider)
        .setStringSetting(
          'theme_mode',
          value,
          description: 'Theme mode: light, dark, or system',
        );
  }

  Future<void> _saveBiometric(bool enabled) async {
    setState(() => _biometricEnabled = enabled);
    await ref
        .read(setupProvider.notifier)
        .setBiometricEnabled(enabled: enabled);
    await ref
        .read(appSettingsDaoProvider)
        .setBoolSetting(
          'biometric_auth_enabled',
          enabled,
          description: 'Biometric auth',
        );
  }

  // _saveSessionTimeout removed - feature no longer used

  Future<void> _saveLibraryName(String value) async {
    await ref
        .read(appSettingsDaoProvider)
        .setStringSetting('library_name', value);
  }

  Future<void> _saveAdminEmail(String value) async {
    await ref
        .read(appSettingsDaoProvider)
        .setStringSetting('admin_email', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Gradient Background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.tertiary.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
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
                    children: [
                      // Profile Section
                      _buildSettingsSection(
                        theme,
                        title: 'Profile',
                        children: [
                          ModernTextField(
                            controller: _libraryNameCtrl,
                            label: 'Library Name',
                            icon: Icons.business_rounded,
                            onChanged: _saveLibraryName,
                          ),
                          const SizedBox(height: 16),
                          ModernTextField(
                            controller: _adminEmailCtrl,
                            label: 'Admin Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: _saveAdminEmail,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Appearance Section
                      _buildSettingsSection(
                        theme,
                        title: 'Appearance',
                        children: [
                          _buildListTile(
                            context,
                            icon: Icons.dark_mode_outlined,
                            title: 'Theme',
                            subtitle: switch (_themeMode) {
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                              _ => 'System Default',
                            },
                            onTap: _showThemeSheet,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Security Section
                      _buildSettingsSection(
                        theme,
                        title: 'Security',
                        children: [
                          _buildSwitchListTile(
                            context,
                            icon: Icons.fingerprint_outlined,
                            title: 'Biometric Login',
                            subtitle: 'Use Face ID or Touch ID',
                            value: _biometricEnabled,
                            onChanged: _saveBiometric,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          // Session timeout removed - user stays logged in indefinitely
                          _buildListTile(
                            context,
                            icon: Icons.logout_rounded,
                            title: 'Sign Out',
                            subtitle: 'Return to login screen',
                            iconColor: theme.colorScheme.error,
                            textColor: theme.colorScheme.error,
                            onTap: _logout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      _buildActionCard(
                        context,
                        icon: Icons.restore_rounded,
                        title: 'Reset to Defaults',
                        subtitle: 'Restore all app settings',
                        destructive: true,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Reset settings?'),
                              content: const Text(
                                'This will reset all your preferences to default. This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(appSettingsDaoProvider)
                                .resetToDefaults();
                            await _loadSettings();
                            if (mounted)
                              CustomNotification.show(
                                context,
                                message: 'Settings reset',
                                type: NotificationType.success,
                              );
                          }
                        },
                      ),
                      const SizedBox(height: 32),

                      _buildFooter(theme),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage app preferences and configurations',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
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
                      color: textColor ?? theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
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
    );
  }

  Widget _buildSwitchListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
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
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool destructive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        Text(
          'scnz.',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        Text(
          'hashimdar141@yahoo.com',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // --- Utility Sheets ---

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
            title: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Appearance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            option('System Default', ThemeMode.system),
            option('Light', ThemeMode.light),
            option('Dark', ThemeMode.dark),
          ],
        );
      },
    );
  }

  // Session timeout functions removed - feature no longer used
}
