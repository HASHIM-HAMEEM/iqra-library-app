import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_text_field.dart';
import 'package:library_registration_app/presentation/widgets/common/primary_button.dart';
import 'package:local_auth/local_auth.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage>
    with TickerProviderStateMixin {
  final _passcodeController = TextEditingController();
  final _confirmPasscodeController = TextEditingController();
  final _localAuth = LocalAuthentication();

  bool _enableBiometric = false;
  bool _isBiometricAvailable = false;
  bool _obscurePasscode = true;
  bool _obscureConfirmPasscode = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricAvailability();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = isAvailable && availableBiometrics.isNotEmpty;
        });
      }
    } catch (e) {
      // Biometric not available
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    }
  }

  bool _validateInputs() {
    if (_passcodeController.text.isEmpty) {
      _showError('Please enter a passcode');
      return false;
    }

    if (_passcodeController.text.length < 4) {
      _showError('Passcode must be at least 4 characters');
      return false;
    }

    if (_passcodeController.text != _confirmPasscodeController.text) {
      _showError('Passcodes do not match');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _completeSetup() async {
    if (!_validateInputs()) return;

    final success = await ref
        .read(setupProvider.notifier)
        .completeSetup(
          passcode: _passcodeController.text,
          enableBiometric: _enableBiometric,
        );

    if (!mounted) return;
    if (success) {
      // Setup completed successfully, now authenticate the user automatically
      await ref
          .read(authProvider.notifier)
          .authenticateWithPassword(_passcodeController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmPasscodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(setupProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 24,
                  tablet: 32,
                  desktop: 40,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 40,
                              tablet: 60,
                              desktop: 80,
                            ),
                          ),

                          // Welcome Section
                          _buildWelcomeSection(theme),

                          SizedBox(
                            height: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 40,
                              tablet: 50,
                              desktop: 60,
                            ),
                          ),

                          // Setup Form
                          _buildSetupForm(theme),

                          if (_isBiometricAvailable) ...[
                            const SizedBox(height: 24),
                            _buildBiometricOption(theme),
                          ],

                          if (setupState.error != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorMessage(setupState.error!, theme),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Complete Setup Button
                  _buildCompleteButton(setupState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme) {
    return Column(
      children: [
        Builder(builder: (context) {
          final size = ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 96,
            tablet: 120,
            desktop: 140,
          ).toDouble();
          final isLight = theme.brightness == Brightness.light;
          final bgColor = isLight
              ? theme.colorScheme.surface
              : theme.colorScheme.surfaceVariant.withValues(alpha: 0.6);
          final outline = theme.colorScheme.outline.withValues(alpha: 0.25);
          return SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: outline),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'IqraLogo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'Welcome, Admin!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 28,
              tablet: 32,
              desktop: 36,
            ),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Set up your admin passcode to secure the library registration system.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSetupForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create Admin Passcode',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        CustomTextField(
          controller: _passcodeController,
          labelText: 'Enter Passcode',
          hintText: 'Minimum 4 characters',
          obscureText: _obscurePasscode,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePasscode ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscurePasscode = !_obscurePasscode;
              });
            },
          ),
          keyboardType: TextInputType.text,
        ),

        const SizedBox(height: 16),

        CustomTextField(
          controller: _confirmPasscodeController,
          labelText: 'Confirm Passcode',
          hintText: 'Re-enter your passcode',
          obscureText: _obscureConfirmPasscode,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPasscode ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPasscode = !_obscureConfirmPasscode;
              });
            },
          ),
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  Widget _buildBiometricOption(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, color: theme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Biometric Authentication',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use fingerprint or face recognition for quick access',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableBiometric,
            onChanged: (value) {
              setState(() {
                _enableBiometric = value;
              });
              // persist preference immediately
              ref.read(setupProvider.notifier).setBiometricEnabled(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(SetupState setupState) {
    return PrimaryButton(
      text: 'Complete Setup',
      onPressed: setupState.isLoading ? null : _completeSetup,
      isLoading: setupState.isLoading,
    );
  }
}
