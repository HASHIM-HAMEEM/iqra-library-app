import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/presentation/layouts/main_layout.dart';
import 'package:library_registration_app/presentation/pages/activity/activity_page.dart';
import 'package:library_registration_app/presentation/pages/auth/auth_page.dart';

import 'package:library_registration_app/presentation/pages/dashboard/dashboard_page.dart';
// Migration page removed - using Supabase only
import 'package:library_registration_app/presentation/pages/settings/settings_page.dart';

import 'package:library_registration_app/presentation/pages/students/add_student_page.dart';
import 'package:library_registration_app/presentation/pages/students/edit_student_page.dart';
import 'package:library_registration_app/presentation/pages/students/student_details_page.dart';
import 'package:library_registration_app/presentation/pages/students/students_page.dart';
import 'package:library_registration_app/presentation/pages/subscriptions/subscription_details_page.dart';
import 'package:library_registration_app/presentation/pages/subscriptions/subscriptions_page.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
final routerProvider = Provider<GoRouter>((ref) {
  // Always derive routing from auth state; auth can be local-only (offline biometric)
  final bool isAuthenticated = ref.watch(isAuthenticatedProvider);

  final String computedInitialLocation = !isAuthenticated ? '/auth' : '/dashboard';

  return GoRouter(
    initialLocation: computedInitialLocation,
    redirect: (context, state) {
      final currentPath = state.uri.path;

      // Check authentication
      if (!isAuthenticated && currentPath != '/auth') {
        debugPrint('[Router] redirect -> /auth (not authenticated). from=$currentPath');
        return '/auth';
      }

      // If trying to access auth while authenticated, redirect to dashboard
      if (isAuthenticated && currentPath == '/auth') {
        debugPrint('[Router] redirect -> /dashboard (already authed). from=$currentPath');
        return '/dashboard';
      }

      return null; // No redirect needed
    },
    routes: [
      // Root route (keeps initial build lightweight; redirect will navigate appropriately)
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      // Auth route
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _buildFadeThroughPage(
          key: state.pageKey,
          child: const AuthPage(),
        ),
      ),

      // Main app routes with layout
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(currentRoute: state.uri.path, child: child);
        },
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const DashboardPage(),
              axis: SharedAxisAxis.scaled,
            ),
          ),

          // Students routes
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const StudentsPage(),
              axis: SharedAxisAxis.horizontal,
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => _buildModalSheetPage(
                  key: state.pageKey,
                  child: const AddStudentPage(),
                ),
              ),
              GoRoute(
                path: 'details/:id',
                pageBuilder: (context, state) {
                  final studentId = state.pathParameters['id']!;
                  return _buildSharedAxisPage(
                    key: state.pageKey,
                    child: StudentDetailsPage(studentId: studentId),
                    axis: SharedAxisAxis.horizontal,
                  );
                },
              ),
              GoRoute(
                path: 'edit/:id',
                pageBuilder: (context, state) {
                  final studentId = state.pathParameters['id']!;
                  return _buildModalSheetPage(
                    key: state.pageKey,
                    child: EditStudentPage(studentId: studentId),
                  );
                },
              ),
            ],
          ),

          // Subscriptions
          GoRoute(
            path: '/subscriptions',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const SubscriptionsPage(),
              axis: SharedAxisAxis.horizontal,
            ),
            routes: [
              GoRoute(
                path: 'details/:id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _buildSharedAxisPage(
                    key: state.pageKey,
                    child: SubscriptionDetailsPage(id: id),
                    axis: SharedAxisAxis.horizontal,
                  );
                },
              ),
            ],
          ),



          // Activity
          GoRoute(
            path: '/activity',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const ActivityPage(),
              axis: SharedAxisAxis.horizontal,
            ),
          ),

          // Reports (placeholder)
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(child: Text('Reports Page - Coming Soon')),
              ),
              axis: SharedAxisAxis.horizontal,
            ),
          ),

          // Settings
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const SettingsPage(),
              axis: SharedAxisAxis.horizontal,
            ),
          ),

          // Migration removed - using Supabase only

          // More -> settings (mobile)
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) => _buildSharedAxisPage(
              key: state.pageKey,
              child: const SettingsPage(),
              axis: SharedAxisAxis.horizontal,
            ),
          ),
        ],
      ),
    ],
  );
});

// --- Page Builders with modern transitions ---

enum SharedAxisAxis { horizontal, vertical, scaled }

CustomTransitionPage<void> _buildSharedAxisPage({
  required LocalKey key,
  required Widget child,
  required SharedAxisAxis axis,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      switch (axis) {
        case SharedAxisAxis.horizontal:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        case SharedAxisAxis.vertical:
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        case SharedAxisAxis.scaled:
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
      }
    },
  );
}

CustomTransitionPage<void> _buildFadeThroughPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final fadeOut = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: fadeIn,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fadeOut),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _buildModalSheetPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    child: child,
    barrierDismissible: true,
    barrierColor: Colors.black54.withAlpha(40),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
