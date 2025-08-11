import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/data/database/dao/app_settings_dao.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';

// Authentication state
class AuthState {

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.lastAuthTime,
    this.sessionTimeoutMinutes = 30,
  });
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final DateTime? lastAuthTime;
  final int sessionTimeoutMinutes;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    DateTime? lastAuthTime,
    int? sessionTimeoutMinutes,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
    );
  }

  bool get isSessionExpired {
    if (lastAuthTime == null) return true;
    final now = DateTime.now();
    final sessionDuration = Duration(minutes: sessionTimeoutMinutes);
    return now.difference(lastAuthTime!) > sessionDuration;
  }
}

// Authentication notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._appSettingsDao, this._setupNotifier)
    : super(const AuthState()) {
    _loadSessionTimeout();
    _checkExistingSession();
  }

  final AppSettingsDao _appSettingsDao;
  final SetupNotifier _setupNotifier;

  Future<void> _loadSessionTimeout() async {
    try {
      final timeout = await _appSettingsDao.getIntSetting(
        'session_timeout_minutes',
      );
      if (timeout != null) {
        state = state.copyWith(sessionTimeoutMinutes: timeout);
      }
    } catch (e) {
      // Use default timeout if error
    }
  }

  // Public method to refresh the session timeout from settings immediately
  Future<void> refreshSessionTimeout() async {
    await _loadSessionTimeout();
  }

  Future<void> _checkExistingSession() async {
    try {
      final lastAuthString = await _appSettingsDao.getStringSetting(
        'last_auth_time',
      );
      if (lastAuthString != null) {
        final lastAuthTime = DateTime.tryParse(lastAuthString);
        if (lastAuthTime != null) {
          final tempState = state.copyWith(lastAuthTime: lastAuthTime);
          if (!tempState.isSessionExpired) {
            state = state.copyWith(
              isAuthenticated: true,
              lastAuthTime: lastAuthTime,
            );
          } else {
            // Session expired, clear it
            await _clearSession();
          }
        }
      }
    } catch (e) {
      // Error checking session, assume not authenticated
    }
  }

  Future<bool> authenticateWithPassword(String password) async {
    state = state.copyWith(isLoading: true);

    try {
      // Validate input
      if (password.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please enter your passcode',
        );
        return false;
      }

      // Use setup provider to validate passcode
      final isValid = await _setupNotifier.validatePasscode(password);

      if (isValid) {
        try {
          final now = DateTime.now();
          await _appSettingsDao.setStringSetting(
            'last_auth_time',
            now.toIso8601String(),
            description: 'Last successful authentication time',
          );

          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            lastAuthTime: now,
          );
          return true;
        } catch (dbError) {
          // Database error during session save
          state = state.copyWith(
            isLoading: false,
            error: 'Database error: Unable to save session. Please try again.',
          );
          return false;
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid passcode. Please try again.',
        );
        return false;
      }
    } catch (e) {
      // Handle different types of errors
      String errorMessage;
      if (e.toString().contains('SQL')) {
        errorMessage =
            'Database error occurred. Please restart the app and try again.';
      } else if (e.toString().contains('secure_storage')) {
        errorMessage = 'Security error: Unable to access stored credentials.';
      } else {
        errorMessage = 'Authentication failed. Please try again.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    state = state.copyWith(isLoading: true);

    try {
      // This would be handled by the calling widget with local_auth
      // Here we just update the state assuming successful biometric auth
      final now = DateTime.now();
      await _appSettingsDao.setStringSetting(
        'last_auth_time',
        now.toIso8601String(),
        description: 'Last successful authentication time',
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        lastAuthTime: now,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Biometric authentication failed: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AuthState();
  }

  Future<void> _clearSession() async {
    try {
      await _appSettingsDao.deleteSetting('last_auth_time');
    } catch (e) {
      // Error clearing session, continue anyway
    }
  }

  void clearError() {
    state = state.copyWith();
  }

  Future<bool> isBiometricEnabled() async {
    try {
      return await _setupNotifier.isBiometricEnabled();
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    try {
      await _setupNotifier.setBiometricEnabled(enabled);
    } catch (e) {
      // Error setting biometric preference
    }
  }
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final appSettingsDao = ref.watch(appSettingsDaoProvider);
  final setupNotifier = ref.watch(setupProvider.notifier);
  return AuthNotifier(appSettingsDao, setupNotifier);
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
