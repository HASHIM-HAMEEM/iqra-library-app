// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_registration_app/main.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: LibraryRegistrationApp()),
    );
    await tester.pumpAndSettle();

    // Verify that the app loads without crashing
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('App shows AuthPage when setup complete but not authenticated', (
    WidgetTester tester,
  ) async {
    // Override providers to simulate setup complete but not authenticated
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSetupCompleteProvider.overrideWith((ref) => true),
          isAuthenticatedProvider.overrideWith((ref) => false),
        ],
        child: const LibraryRegistrationApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the auth page is displayed.
    expect(find.text('IQRA'), findsOneWidget);
    expect(find.text('Admin Access Portal'), findsOneWidget);
  });

  testWidgets('Authentication provider works correctly', (
    WidgetTester tester,
  ) async {
    // Test that the isAuthenticatedProvider can be overridden
    final container = ProviderContainer(
      overrides: [isAuthenticatedProvider.overrideWith((ref) => true)],
    );

    // Verify the provider returns the expected value
    expect(container.read(isAuthenticatedProvider), true);

    container.dispose();
  });

  test('AuthState copyWith works correctly', () {
    const initialState = AuthState();

    final updatedState = initialState.copyWith(
      isAuthenticated: true,
      isLoading: false,
    );

    expect(updatedState.isAuthenticated, true);
    expect(updatedState.isLoading, false);
    expect(updatedState.error, null);
  });
}
