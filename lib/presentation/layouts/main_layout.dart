// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainLayout extends ConsumerStatefulWidget {

  const MainLayout({
    required this.child, required this.currentRoute, super.key,
  });
  final Widget child;
  final String currentRoute;

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      try {
        if (Supabase.instance.client.auth.currentSession != null) {
          Supabase.instance.client.auth
              .refreshSession()
              .then((_) {}, onError: (_) {});
        }
      } catch (_) {}
      ref.read(authProvider.notifier).validateSession();
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
    final isFullScreenForm =
        path.startsWith('/students/add') || path.startsWith('/students/edit');
    // Show side navigation only on wide tablets and desktop
    final showSideNav = !hideNavForActivity && ((isTablet && width >= 900) || isDesktop);
    // Show bottom navigation on mobile and small tablets (portrait)
    final showBottomNav =
        !hideNavForActivity &&
        !showSideNav && // never show bottom nav when side nav is visible
        (!isDesktop && (ResponsiveUtils.isMobile(context) || (isTablet && width < 900))) &&
        !isFullScreenForm;
    // Only show the top center nav on true desktop platforms (or web),
    // and never when a side nav is already visible (prevents duplicate navs on tablets in landscape).
    final isDesktopOS = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final showCenterTopNav = isDesktopOS && !hideNavForActivity && !showSideNav;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Top Navigation Bar
          if (!hideNavForActivity) _buildTopNavigationBar(context, theme, showCenterTopNav),

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
    bool showCenterTopNav,
  ) {
    // Do not render the profile icon in the top bar; it will be shown in the dashboard header
    return Container(
      height: 64,
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
                  // Removed brand glyph per design request

                  // Center nav (desktop only)
                  if (showCenterTopNav)
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: RepaintBoundary(
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                               decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.75),
                                 borderRadius: BorderRadius.circular(14),
                                 border: Border.all(
                                   color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                 ),
                               ),
                               child: SingleChildScrollView(
                                 scrollDirection: Axis.horizontal,
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     _buildNavItem(
                                       context,
                                       'Dashboard',
                                       '/dashboard',
                                       Icons.dashboard_outlined,
                                     ),
                                     const SizedBox(width: 6),
                                     _buildNavItem(
                                       context,
                                       'Students',
                                       '/students',
                                       Icons.people_outlined,
                                     ),
                                     const SizedBox(width: 6),
                                     _buildNavItem(
                                       context,
                                       'Subscriptions',
                                       '/subscriptions',
                                       Icons.card_membership_outlined,
                                     ),
                                     const SizedBox(width: 6),
                                     _buildNavItem(
                                       context,
                                       'Recent Activity',
                                       '/activity',
                                       Icons.access_time_outlined,
                                     ),
                                   ],
                                 ),
                               ),
                             ),
                           ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  // User Menu moved to dashboard header; keep top bar clean
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
    final isActive = widget.currentRoute == route;

    final Color chipBg = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final Color textColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.80);
    final Color borderColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.22)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToRoute(context, route),
        borderRadius: BorderRadius.circular(12),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(12),
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
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.75),
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
          visible: !(ResponsiveUtils.isLandscape(context) && !ResponsiveUtils.isDesktop(context)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                onTap: () => _navigateToRoute(context, '/settings'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, size: 22, color: theme.colorScheme.onSurfaceVariant),
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
    final isActive = widget.currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          onTap: () {
            _navigateToRoute(context, route);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                if (isActive) const SizedBox(width: 10) else const SizedBox(width: 14),
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
          borderRadius: BorderRadius.circular(30),
          child: RepaintBoundary(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(30),
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
                  borderRadius: BorderRadius.circular(24),
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
                                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: theme.textTheme.labelMedium!.copyWith(
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.65),
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

  Widget _buildUserMenu(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        // Show a simple dialog for logout instead of popup menu
        showDialog<AlertDialog>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Profile'),
              content: const Text('What would you like to do?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(authProvider.notifier).logout();
                  },
                  child: const Text('Logout'),
                ),
              ],
            );
          },
        );
      },
      child: Builder(builder: (context) {
        final orientation = MediaQuery.of(context).orientation;
        final isTablet = ResponsiveUtils.isTablet(context);
        final isDesktop = ResponsiveUtils.isDesktop(context);

        // Larger, responsive diameter across devices/orientations
        double diameter;
        if (isDesktop) {
          diameter = 68;
        } else if (isTablet) {
          diameter = orientation == Orientation.portrait ? 72 : 64;
        } else {
          // mobile
          diameter = orientation == Orientation.portrait ? 60 : 56;
        }

        // Cap to top bar height (64) minus small padding for breathing space
        diameter = diameter.clamp(0, 56).toDouble();

        final iconSize = (diameter * 0.58).clamp(24.0, 40.0);

        // Neutral, theme-aware colors that work in both light and dark
        final isLight = theme.brightness == Brightness.light;
        final cs = theme.colorScheme;
        final bgColor = isLight
            ? cs.surface.withValues(alpha: 0.98)
            : cs.surfaceVariant.withValues(alpha: 0.75);
        final fgColor = cs.onSurface;

        return Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            size: iconSize,
            color: fgColor,
          ),
        );
      }),
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    context.go(route);
  }
}
// Fixed by removing the unused _showGlobalExportSheet method
