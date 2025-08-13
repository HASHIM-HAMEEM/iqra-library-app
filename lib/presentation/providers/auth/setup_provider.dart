import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Setup state
class SetupState {

  const SetupState({
    this.isSetupComplete = false,
    this.isLoading = false,
    this.error,
  });
  final bool isSetupComplete;
  final bool isLoading;
  final String? error;

  SetupState copyWith({bool? isSetupComplete, bool? isLoading, String? error}) {
    return SetupState(
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Setup notifier
class SetupNotifier extends StateNotifier<SetupState> {
  SetupNotifier() : super(const SetupState()) {
    _checkSetupStatus();
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _passcodeKey = 'admin_passcode_hash';
  static const String _biometricKey = 'biometric_enabled';
  static const String _setupCompleteKey = 'setup_complete';

  Future<void> _checkSetupStatus() async {
    try {
      final setupComplete = await _secureStorage.read(key: _setupCompleteKey);
      state = state.copyWith(isSetupComplete: setupComplete == 'true');
    } catch (e) {
      // Error checking setup status, assume not complete
      state = state.copyWith(isSetupComplete: false);
    }
  }

  Future<bool> completeSetup({
    required String passcode,
    required bool enableBiometric,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      // Validate input
      if (passcode.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please enter a passcode',
        );
        return false;
      }

      if (passcode.length < 4) {
        state = state.copyWith(
          isLoading: false,
          error: 'Passcode must be at least 4 characters long',
        );
        return false;
      }

      // Hash the passcode for secure storage
      final bytes = utf8.encode(passcode);
      final digest = sha256.convert(bytes);
      final hashedPasscode = digest.toString();

      // Store the hashed passcode and preferences
      await _secureStorage.write(key: _passcodeKey, value: hashedPasscode);
      await _secureStorage.write(
        key: _biometricKey,
        value: enableBiometric.toString(),
      );
      await _secureStorage.write(key: _setupCompleteKey, value: 'true');

      state = state.copyWith(isSetupComplete: true, isLoading: false);

      return true;
    } catch (e) {
      // Handle different types of errors
      String errorMessage;
      if (e.toString().contains('secure_storage') ||
          e.toString().contains('keychain')) {
        errorMessage =
            'Unable to securely store your passcode. Please check device security settings.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            'Permission denied. Please allow the app to access secure storage.';
      } else {
        errorMessage = 'Setup failed. Please try again.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> validatePasscode(String passcode) async {
    try {
      final storedHash = await _secureStorage.read(key: _passcodeKey);
      if (storedHash == null) return false;

      final bytes = utf8.encode(passcode);
      final digest = sha256.convert(bytes);
      final inputHash = digest.toString();

      return inputHash == storedHash;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricKey);
      return enabled == 'true';
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    try {
      await _secureStorage.write(key: _biometricKey, value: enabled.toString());
    } catch (e) {
      // Error setting biometric preference
    }
  }

  Future<void> resetSetup() async {
    try {
      await _secureStorage.delete(key: _passcodeKey);
      await _secureStorage.delete(key: _biometricKey);
      await _secureStorage.delete(key: _setupCompleteKey);

      state = const SetupState();
    } catch (e) {
      state = state.copyWith(error: 'Failed to reset setup: $e');
    }
  }

  void clearError() {
    state = state.copyWith();
  }
}

// Setup provider
final setupProvider = StateNotifierProvider<SetupNotifier, SetupState>((ref) {
  return SetupNotifier();
});

// Convenience providers
final isSetupCompleteProvider = Provider<bool>((ref) {
  return ref.watch(setupProvider).isSetupComplete;
});

final setupLoadingProvider = Provider<bool>((ref) {
  return ref.watch(setupProvider).isLoading;
});

final setupErrorProvider = Provider<String?>((ref) {
  return ref.watch(setupProvider).error;
});
