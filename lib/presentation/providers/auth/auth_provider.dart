import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:library_registration_app/core/services/connectivity_service.dart';
// import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/data/services/app_settings_service.dart';
import 'package:library_registration_app/data/services/supabase_service.dart';

import 'package:library_registration_app/presentation/providers/database_provider.dart';

// Authentication state
class AuthState {

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.lastAuthTime,
    this.sessionTimeoutMinutes = 30,
    this.user,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.requiresReauth = false,
    this.lastKnownEmail,
  });
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final DateTime? lastAuthTime;
  final int sessionTimeoutMinutes;
  final User? user;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final bool requiresReauth;
  final String? lastKnownEmail;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    DateTime? lastAuthTime,
    int? sessionTimeoutMinutes,
    User? user,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool? requiresReauth,
    String? lastKnownEmail,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      user: user ?? this.user,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: lockoutUntil,
      requiresReauth: requiresReauth ?? this.requiresReauth,
      lastKnownEmail: lastKnownEmail ?? this.lastKnownEmail,
    );
  }

  bool get isSessionExpired {
    if (lastAuthTime == null) return true;
    final now = DateTime.now();
    final sessionDuration = Duration(minutes: sessionTimeoutMinutes);
    return now.difference(lastAuthTime!) > sessionDuration;
  }

  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  Duration? get lockoutTimeRemaining {
    if (!isLockedOut) return null;
    return lockoutUntil!.difference(DateTime.now());
  }
}

// Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._appSettingsService, this._supabaseService)
    : super(const AuthState()) {
    _loadSessionTimeout();
    _loadFailedAttempts();
    _checkExistingSession();
    _listenToAuthChanges();
  }

  final AppSettingsService _appSettingsService;
  final SupabaseService _supabaseService;
  
  // Security constants
  static const int _maxFailedAttempts = 13;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static const Duration _sessionWarningThreshold = Duration(minutes: 5);

  Future<void> _loadSessionTimeout() async {
    try {
      final timeout = await _appSettingsService.getIntSetting(
        'session_timeout_minutes',
      );
      if (timeout != null) {
        state = state.copyWith(sessionTimeoutMinutes: timeout);
      }
    } catch (e) {
      // Use default timeout if error
    }
  }

  Future<void> _loadFailedAttempts() async {
    try {
      final attempts = await _appSettingsService.getIntSetting('failed_auth_attempts') ?? 0;
    final lockoutString = await _appSettingsService.getStringSetting('lockout_until');
      DateTime? lockoutUntil;
      if (lockoutString != null) {
        lockoutUntil = DateTime.tryParse(lockoutString);
        // Clear expired lockouts
        if (lockoutUntil != null && DateTime.now().isAfter(lockoutUntil)) {
          await _clearLockout();
          lockoutUntil = null;
        }
      }
      state = state.copyWith(
        failedAttempts: attempts,
        lockoutUntil: lockoutUntil,
      );
    } catch (e) {
      // Use default values if error
    }
  }

  Future<void> _incrementFailedAttempts() async {
    final newAttempts = state.failedAttempts + 1;
    await _appSettingsService.setIntSetting(
      'failed_auth_attempts',
      newAttempts,
      description: 'Number of failed authentication attempts',
    );
    
    if (newAttempts >= _maxFailedAttempts) {
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      await _appSettingsService.setStringSetting(
        'lockout_until',
        lockoutUntil.toIso8601String(),
        description: 'Account lockout expiration time',
      );
      state = state.copyWith(
        failedAttempts: newAttempts,
        lockoutUntil: lockoutUntil,
      );
    } else {
      state = state.copyWith(failedAttempts: newAttempts);
    }
  }

  Future<void> _clearFailedAttempts() async {
    await _appSettingsService.deleteSetting('failed_auth_attempts');
    await _clearLockout();
    state = state.copyWith(
      failedAttempts: 0,
      lockoutUntil: null,
    );
  }

  Future<void> _clearLockout() async {
    await _appSettingsService.deleteSetting('lockout_until');
  }

  // Public method to refresh the session timeout from settings immediately
  Future<void> refreshSessionTimeout() async {
    await _loadSessionTimeout();
  }

  void _listenToAuthChanges() {
    _supabaseService.authStateChanges.listen((authState) {
      final user = authState.session?.user;
      if (user != null) {
        // User is authenticated
        final now = DateTime.now();
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          lastAuthTime: now,
          lastKnownEmail: user.email,
        );
        // Save auth time to local storage
        () async {
          try {
            await _appSettingsService.setStringSetting(
              'last_auth_time',
              now.toIso8601String(),
              description: 'Last successful authentication time',
            );
            if ((user.email ?? '').isNotEmpty) {
              await _appSettingsService.setStringSetting(
                'last_admin_email',
                user.email ?? '',
                description: 'Last signed in admin email',
              );
            }
          } catch (_) {}
        }();
      } else {
        // User is not authenticated
        state = state.copyWith(
          isAuthenticated: false,
          user: null,
        );
        _clearSession();
      }
    });
  }

  Future<void> _checkExistingSession() async {
    try {
      // Check if user is already authenticated with Supabase
      final user = _supabaseService.currentUser;
      if (user != null) {
        final lastAuthString = await _appSettingsService.getStringSetting(
          'last_auth_time',
        );
        DateTime? lastAuthTime;
        if (lastAuthString != null) {
          lastAuthTime = DateTime.tryParse(lastAuthString);
        }
        
        final tempState = state.copyWith(lastAuthTime: lastAuthTime);
        if (lastAuthTime == null || !tempState.isSessionExpired) {
          state = state.copyWith(
            isAuthenticated: true,
            user: user,
            lastAuthTime: lastAuthTime ?? DateTime.now(),
          );
        } else {
          // Session expired, sign out
          await _supabaseService.signOut();
        }
      }
    } catch (e) {
      // Error checking session, assume not authenticated
    }
  }

  Future<bool> authenticateWithPassword(String email, String password) async {
    // Check if account is locked out
    if (state.isLockedOut) {
      final remaining = state.lockoutTimeRemaining;
      final minutes = remaining?.inMinutes ?? 0;
      state = state.copyWith(
        isLoading: false,
        error: 'Account temporarily locked. Try again in $minutes minutes.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Enhanced input validation
      if (email.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please enter your email address',
        );
        return false;
      }

      if (password.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please enter your password',
        );
        return false;
      }

      // Basic email format validation
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please enter a valid email address',
        );
        return false;
      }

      // Directly attempt authentication with a short retry on transient network errors
      const int maxAttempts = 13;
      int attempt = 0;
      while (true) {
        try {
          await _supabaseService.signInWithPassword(email.trim(), password);
          break; // success
        } catch (e) {
          attempt++;
          final String lower = e.toString().toLowerCase();
          final bool isTransientNetwork =
              lower.contains('socket') || lower.contains('network') || lower.contains('timeout');
          if (!isTransientNetwork || attempt >= maxAttempts) {
            rethrow;
          }
          // Exponential backoff: 300ms, 900ms
          final delayMs = 300 * attempt * attempt;
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
      
      // Authentication successful - clear failed attempts
      await _clearFailedAttempts();
      // Mark that a real credential sign-in occurred. Used to gate biometrics visibility.
      await _appSettingsService.setBoolSetting('has_signed_in_once', true,
          description: 'Admin has completed at least one credential login');
      // Persist last known admin email for offline biometric display
      try {
        await _appSettingsService.setStringSetting(
          'last_admin_email',
          email.trim(),
          description: 'Last signed in admin email',
        );
      } catch (_) {}
      state = state.copyWith(lastKnownEmail: email.trim());
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      // Increment failed attempts for authentication failures
      await _incrementFailedAttempts();
      
      // Handle different types of errors with enhanced messaging
      String errorMessage;
      if (e is AuthException) {
        switch (e.statusCode) {
          case '400':
            errorMessage = 'Invalid email or password. Please check your credentials.';
            break;
          case '401':
            errorMessage = 'Invalid email or password.';
            break;
          case '422':
            errorMessage = 'Email not confirmed. Please check your email for a confirmation link.';
            break;
          case '429':
            errorMessage = 'Too many login attempts. Please wait before trying again.';
            break;
          case '500':
            errorMessage = 'Server error. Please try again later.';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Authentication failed. Please try again.';
        }
      } else if (e.toString().toLowerCase().contains('network') || 
                 e.toString().toLowerCase().contains('socket') ||
                 e.toString().toLowerCase().contains('connection') ||
                 e.toString().toLowerCase().contains('timeout')) {
        errorMessage = 'Couldn\'t reach the authentication service. Please try again.';
      } else {
        errorMessage = 'Authentication failed. Please check your credentials and try again.';
      }

      // Add lockout warning if approaching limit
      final attemptsRemaining = _maxFailedAttempts - state.failedAttempts;
      if (attemptsRemaining <= 2 && attemptsRemaining > 0) {
        errorMessage += ' ($attemptsRemaining attempts remaining)';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> authenticateWithBiometric({bool allowOffline = false}) async {
    // Check if account is locked out
    if (state.isLockedOut) {
      final remaining = state.lockoutTimeRemaining;
      final minutes = remaining?.inMinutes ?? 0;
      state = state.copyWith(
        isLoading: false,
        error: 'Account temporarily locked. Try again in $minutes minutes.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // If we already have a valid Supabase session, use it
      final user = _supabaseService.currentUser;
      final session = _supabaseService.currentSession;
      if (user != null && session != null) {
        // Optional: if session has explicit expiry and it's in the past, treat as no session
        if (session.expiresAt != null &&
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000).isBefore(DateTime.now())) {
          // fall through to offline path if allowed
        } else {
          final now = DateTime.now();
          await _appSettingsService.setStringSetting(
            'last_auth_time',
            now.toIso8601String(),
            description: 'Last successful authentication time',
          );
          await _clearFailedAttempts();
          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            lastAuthTime: now,
            user: user,
            requiresReauth: false,
          );
          return true;
        }
      }

      // No valid Supabase session. If offline biometric is allowed, unlock locally.
      if (allowOffline) {
        final now = DateTime.now();
        try {
          await _appSettingsService.setStringSetting(
            'last_auth_time',
            now.toIso8601String(),
            description: 'Last successful authentication time',
          );
        } catch (_) {}
        String? lastEmail;
        try {
          lastEmail = await _appSettingsService.getStringSetting('last_admin_email');
        } catch (_) {}
        await _clearFailedAttempts();
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          lastAuthTime: now,
          lastKnownEmail: lastEmail,
          // user remains null; app may require reauth for server ops
          requiresReauth: true,
        );
        return true;
      }

      // Otherwise, require credentials because we cannot identify a Supabase session
      state = state.copyWith(
        isLoading: false,
        error: 'No valid session found. Please sign in with email and password first.',
      );
      return false;
    } catch (e) {
      // Don't increment failed attempts for biometric failures as they're handled by the OS
      String errorMessage;
      if (e.toString().toLowerCase().contains('network') || 
          e.toString().toLowerCase().contains('connection')) {
        errorMessage = 'Network error during biometric authentication. Please try again.';
      } else {
        errorMessage = 'Biometric authentication failed. Please try again or use password.';
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    }
  }

  Future<void> logout({bool hard = false}) async {
    try {
      if (hard) {
        await _supabaseService.signOut();
      }
      await _clearSession();
      // Treat logout as an app lock by default (keep Supabase session tokens)
      state = state.copyWith(
        isAuthenticated: false,
        user: null,
        requiresReauth: true,
        error: null,
      );
    } catch (e) {
      await _clearSession();
      state = state.copyWith(
        isAuthenticated: false,
        user: null,
        requiresReauth: true,
        error: null,
      );
    }
  }

  Future<void> _clearSession() async {
    try {
      await _appSettingsService.deleteSetting('last_auth_time');
    } catch (e) {
      // Error clearing session, continue anyway
    }

    // Do NOT delete 'last_admin_email' here. It must persist to display
    // the admin identity after biometric unlock without a live session.
  }

  void clearError() {
    state = state.copyWith();
  }

  /// Check if session is approaching expiration and needs warning
  bool get shouldWarnSessionExpiry {
    if (state.lastAuthTime == null || !state.isAuthenticated) return false;
    final now = DateTime.now();
    final sessionDuration = Duration(minutes: state.sessionTimeoutMinutes);
    final timeUntilExpiry = sessionDuration - now.difference(state.lastAuthTime!);
    return timeUntilExpiry <= _sessionWarningThreshold && timeUntilExpiry > Duration.zero;
  }

  /// Extend current session (useful for "keep me logged in" functionality)
  Future<void> extendSession() async {
    if (!state.isAuthenticated) return;
    
    try {
      // Validate that the Supabase session is still valid
      final session = _supabaseService.currentSession;
      if (session == null) {
        await logout();
        return;
      }

      final now = DateTime.now();
      await _appSettingsService.setStringSetting(
        'last_auth_time',
        now.toIso8601String(),
        description: 'Last successful authentication time',
      );

      state = state.copyWith(lastAuthTime: now);
    } catch (e) {
      // If extending session fails, force logout for security
      await logout();
    }
  }

  /// Force re-authentication for sensitive operations
  void requireReauth() {
    state = state.copyWith(requiresReauth: true);
  }

  /// Clear re-authentication requirement after successful auth
  void clearReauthRequirement() {
    state = state.copyWith(requiresReauth: false);
  }

  /// Check session validity and auto-logout if expired
  Future<void> validateSession() async {
    if (!state.isAuthenticated) return;

    try {
      // Check local session expiry
      if (state.isSessionExpired) {
        await logout();
        return;
      }

      // Check Supabase session validity
      final session = _supabaseService.currentSession;
      if (session == null) {
        await logout();
        return;
      }

      // Check if Supabase session is expired
      if (session.expiresAt != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (expiryTime.isBefore(DateTime.now())) {
          await logout();
          return;
        }
      }
    } catch (e) {
      // If validation fails, logout for security
      await logout();
    }
  }

}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final appSettingsService = ref.watch(appSettingsServiceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthNotifier(appSettingsService, supabaseService);
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated && !authState.isSessionExpired;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});
