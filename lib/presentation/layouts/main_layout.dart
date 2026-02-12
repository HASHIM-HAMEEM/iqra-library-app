// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/export/export_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/app_bottom_sheet.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({
    required this.child,
    required this.currentRoute,
    super.key,
  });
  final Widget child;
  final String currentRoute;

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No session validation timer - user stays logged in until they explicitly logout
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh session silently in background - don't logout on any failure
      try {
        final authNotifier = ref.read(authProvider.notifier);
        if (authNotifier.currentSession != null) {
          unawaited(authNotifier.refreshSession());
        }
      } catch (_) {}
      // No validateSession call - user stays logged in
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final width = MediaQuery.of(context).size.width;
    final path = widget.currentRoute;
    final hideNavForActivity = path.startsWith('/activity');
    final isStudentEditPath = RegExp(r'^/students/[^/]+/edit$').hasMatch(path);
    final isFullScreenForm =
        path.startsWith('/students/add') ||
        path.startsWith('/students/edit') ||
        isStudentEditPath;
    // Show side navigation only on wide tablets and desktop
    final showSideNav =
        !hideNavForActivity && ((isTablet && width >= 900) || isDesktop);
    // Show bottom navigation on mobile and small tablets (portrait)
    final showBottomNav =
        !hideNavForActivity &&
        !showSideNav && // never show bottom nav when side nav is visible
        (!isDesktop &&
            (ResponsiveUtils.isMobile(context) || (isTablet && width < 900))) &&
        !isFullScreenForm;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Top Navigation Bar
          if (!hideNavForActivity)
            _buildTopNavigationBar(context, theme, showSideNav),

          // Main Content
          Expanded(
            child: Row(
              children: [
                // Side Navigation (wide tablets/desktop)
                if (showSideNav) _buildSideNavigation(context, theme),

                // Main Content Area
                Expanded(child: widget.child),
              ],
            ),
          ),

          // Bottom Navigation (mobile and small tablets)
          if (showBottomNav) _buildBottomNavigation(context, theme),
        ],
      ),
    );
  }

  Widget _buildTopNavigationBar(
    BuildContext context,
    ThemeData theme,
    bool showSideNav,
  ) {
    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxContentWidth(context),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  // Brand mark
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: AppRadius.borderMd,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'I',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'IQRA',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  // Center nav removed - navigation is now only via side nav or bottom nav
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String label,
    String route,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isActive =
        widget.currentRoute == route ||
        widget.currentRoute.startsWith('$route/');

    final chipBg = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final textColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.80);
    final borderColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.22)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToRoute(context, route),
        borderRadius: AppRadius.borderMd,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : null,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: chipBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context, ThemeData theme) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: RepaintBoundary(
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.75),
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildSideNavItem(
                context,
                'Dashboard',
                '/dashboard',
                Icons.dashboard_outlined,
              ),
              const SizedBox(height: 8),
              _buildSideNavItem(
                context,
                'Students',
                '/students',
                Icons.people_outlined,
              ),
              const SizedBox(height: 8),
              _buildSideNavItem(
                context,
                'Subscriptions',
                '/subscriptions',
                Icons.card_membership_outlined,
              ),
              const SizedBox(height: 8),
              _buildSideNavItem(
                context,
                'Recent Activity',
                '/activity',
                Icons.access_time_outlined,
              ),
              const SizedBox(height: 8),
              _buildSideNavItem(
                context,
                'Settings',
                '/settings',
                Icons.settings_outlined,
              ),
              const SizedBox(height: 8),
              // Replace Data Migration with Export Data
              Visibility(
                visible:
                    !(ResponsiveUtils.isLandscape(context) &&
                        !ResponsiveUtils.isDesktop(context)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.borderMd,
                      hoverColor: theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      onTap: () => _showExportDialog(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 22,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Export Data',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavItem(
    BuildContext context,
    String label,
    String route,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isActive =
        widget.currentRoute == route ||
        widget.currentRoute.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderMd,
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          onTap: () {
            _navigateToRoute(context, route);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderMd,
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : null,
              border: isActive
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: isActive ? 4 : 0,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: AppRadius.borderXs,
                  ),
                ),
                if (isActive)
                  const SizedBox(width: 10)
                else
                  const SizedBox(width: 14),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context, ThemeData theme) {
    final routes = ['/dashboard', '/students', '/subscriptions', '/settings'];
    final labels = ['Home', 'Students', 'Subscriptions', 'Settings'];
    final icons = [
      Icons.home_outlined,
      Icons.people_outline,
      Icons.credit_card,
      Icons.settings_outlined,
    ];
    final currentIndex = routes
        .indexOf(widget.currentRoute)
        .clamp(0, routes.length - 1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: AppRadius.borderPill,
          child: RepaintBoundary(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: AppRadius.borderPill,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(routes.length, (i) {
                  final isActive = i == currentIndex;

                  return Expanded(
                    child: InkWell(
                      borderRadius: AppRadius.borderXl,
                      onTap: () => _navigateToRoute(context, routes[i]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: isActive
                                ? Stack(
                                    key: const ValueKey('active'),
                                    alignment: Alignment.center,
                                    children: [
                                      // Subtle icon-shaped glow (stays within icon boundary)
                                      Icon(
                                        icons[i],
                                        size: 30,
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.18),
                                      ),
                                      Icon(
                                        icons[i],
                                        size: 26,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  )
                                : Icon(
                                    key: const ValueKey('inactive'),
                                    icons[i],
                                    size: 26,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: theme.textTheme.labelMedium!.copyWith(
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.65,
                                    ),
                            ),
                            child: Text(labels[i]),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    context.go(route);
  }

  void _showExportDialog(BuildContext context) {
    final theme = Theme.of(context);
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Export Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _exportOption(
              theme: theme,
              icon: Icons.download_outlined,
              title: 'Export All Data',
              subtitle: 'Students, subscriptions, and activity logs',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(context, ExportType.all);
              },
            ),
            _exportOption(
              theme: theme,
              icon: Icons.people_outline,
              title: 'Export Students Only',
              subtitle: 'Student information and details',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(context, ExportType.students);
              },
            ),
            _exportOption(
              theme: theme,
              icon: Icons.card_membership_outlined,
              title: 'Export Subscriptions Only',
              subtitle: 'Subscription plans and payments',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(context, ExportType.subscriptions);
              },
            ),
            _exportOption(
              theme: theme,
              icon: Icons.history_outlined,
              title: 'Export Activity Logs Only',
              subtitle: 'System activity and audit trail',
              onTap: () {
                Navigator.of(ctx).pop();
                _showExportSheet(context, ExportType.activityLogs);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _exportOption({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
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

  void _showExportSheet(BuildContext context, ExportType exportType) {
    final theme = Theme.of(context);
    showAppBottomSheet<void>(
      context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final exportState = ref.watch(exportNotifierProvider);
            final exportNotifier = ref.read(exportNotifierProvider.notifier);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _exportTitle(exportType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (exportState.status == ExportStatus.loading) ...[
                  CircularProgressIndicator(
                    value: exportState.progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Exporting data... ${(exportState.progress * 100).toInt()}%',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else if (exportState.status == ExportStatus.success) ...[
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Export completed successfully!',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'File saved to: ${exportState.filePath?.split('/').last}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: exportNotifier.shareExportedFile,
                    icon: const Icon(Icons.share),
                    label: const Text('Share File'),
                  ),
                ] else if (exportState.status == ExportStatus.error) ...[
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Export failed',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exportState.errorMessage ?? 'Unknown error occurred',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: exportNotifier.resetState,
                    child: const Text('Try Again'),
                  ),
                ] else ...[
                  Icon(
                    Icons.download_outlined,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ready to export',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a format to download.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => exportNotifier.exportData(exportType),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Excel'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            exportNotifier.exportDataCsv(exportType),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('CSV'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (exportState.status != ExportStatus.loading)
                  TextButton(
                    onPressed: () {
                      exportNotifier.resetState();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Close'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _exportTitle(ExportType type) {
    switch (type) {
      case ExportType.all:
        return 'Export All Data';
      case ExportType.students:
        return 'Export Students Data';
      case ExportType.subscriptions:
        return 'Export Subscriptions Data';
      case ExportType.activityLogs:
        return 'Export Activity Logs';
    }
  }
}
