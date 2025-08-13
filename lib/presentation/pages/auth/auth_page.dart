import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/presentation/providers/auth/auth_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_text_field.dart';
import 'package:library_registration_app/presentation/widgets/common/primary_button.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:library_registration_app/presentation/providers/auth/setup_provider.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/widgets/common/custom_notification.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _localAuth = LocalAuthentication();
  bool get _inTest => Platform.environment.containsKey('FLUTTER_TEST');

  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricAutoPrompted = false;
  bool _authInProgress = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check when returning to this page in case settings changed
    _checkBiometricAvailability();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      if (!AppConfig.enableBiometricAuth) {
        if (mounted) setState(() => _biometricAvailable = false);
        return;
      }

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      // Consider any non-empty enrollment acceptable (some devices report only 'weak')
      final hasAnyBiometric = enrolled.isNotEmpty;
      // Respect user's preference from setup/settings
      final enabledPref = await ref.read(setupProvider.notifier).isBiometricEnabled();
      // Require the admin to have signed in at least once before offering biometric
      final hasSignedInOnce =
          (await ref.read(appSettingsDaoProvider).getBoolSetting('has_signed_in_once')) ?? false;
      final canShowIcon = isDeviceSupported && canCheck && hasAnyBiometric && enabledPref && hasSignedInOnce;
      if (mounted) setState(() => _biometricAvailable = canShowIcon);

      // Optional auto-prompt once if conditions are good and nothing loading
      if (mounted &&
          canShowIcon &&
          !_biometricAutoPrompted &&
          !ref.read(authProvider).isLoading &&
          !_inTest) {
        _biometricAutoPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _authenticateWithBiometric();
        });
      }
      debugPrint(
        '[Biometric] deviceSupported=$isDeviceSupported canCheck=$canCheck enrolled=$enrolled',
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[Biometric] capability check exception: ${e.code} ${e.message}',
      );
      if (mounted) setState(() => _biometricAvailable = false);
    } catch (e) {
      debugPrint('[Biometric] capability check error: $e');
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _authenticateWithPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authProvider.notifier)
        .authenticateWithPassword(_emailController.text, _passwordController.text);
    if (!success) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        _showErrorNotification(error);
        ref.read(authProvider.notifier).clearError();
      }
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_authInProgress) return; // debounce multiple taps
    setState(() => _authInProgress = true);
    try {
      debugPrint('[Biometric] starting authenticate');
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock Library Admin with biometrics',
        options: const AuthenticationOptions(
          biometricOnly: !AppConfig.allowDeviceCredentialFallback,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Library Admin',
            cancelButton: 'Use password',
            biometricNotRecognized: 'Not recognized—try again',
            biometricRequiredTitle: 'Biometric required',
            goToSettingsButton: 'Open Settings',
            goToSettingsDescription:
                'Set up fingerprint or face unlock to use biometrics in Library Admin.',
          ),
        ],
      );

      if (didAuthenticate) {
        final success = await ref
            .read(authProvider.notifier)
            // Allow offline biometric unlock if no Supabase session exists
            .authenticateWithBiometric(allowOffline: true);
        if (!success) {
          final error = ref.read(authProvider).error;
          if (error != null) {
            _showErrorNotification(error);
            ref.read(authProvider.notifier).clearError();
          }
        }
        debugPrint('[Biometric] success');
      } else {
        // User canceled or system returned false without exception
        _showErrorNotification("Authentication canceled");
        debugPrint('[Biometric] canceled/false');
      }
    } on PlatformException catch (e) {
      debugPrint('[Biometric] PlatformException ${e.code}: ${e.message}');
      switch (e.code) {
        case auth_error.notAvailable:
          _showErrorNotification("This device doesn't support biometrics.");
          break;
        case auth_error.notEnrolled:
          _showErrorNotification("No biometric enrolled. Add a fingerprint/face in Settings.");
          break;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          _showErrorNotification("Too many attempts. Try again later or use password.");
          break;
        case auth_error.passcodeNotSet:
          _showErrorNotification("Set a device screen lock to use biometrics.");
          break;
        case auth_error.otherOperatingSystem:
          _showErrorNotification("Biometrics not supported on this OS version.");
          break;
        default:
          _showErrorNotification("Couldn't verify. Please try again.");
      }
    } catch (e) {
      debugPrint('[Biometric] error: $e');
      _showErrorNotification("Couldn't verify. Please try again.");
    } finally {
      if (mounted) setState(() => _authInProgress = false);
    }
  }

  void _showErrorNotification(String message) {
    if (_inTest) return; // avoid scheduling notification timers in tests
    if (!mounted) return;
    CustomNotification.show(
      context,
      message: message,
      type: NotificationType.error,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.isMobile(context)
                      ? double.infinity
                      : 420,
                ),
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          Container(
                            width: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 100,
                              tablet: 120,
                              desktop: 140,
                            ),
                            height: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 100,
                              tablet: 120,
                              desktop: 140,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Builder(builder: (context) {
                                final theme = Theme.of(context);
                                final isLight = theme.brightness == Brightness.light;
                                final bgColor = isLight
                                    ? theme.colorScheme.inverseSurface.withValues(alpha: 0.9)
                                    : theme.colorScheme.surfaceVariant.withValues(alpha: 0.6);
                                final outline = theme.colorScheme.outline.withValues(alpha: 0.25);
                                return DecoratedBox(
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
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Title + biometric icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  AppConfig.appName,
                                  style: GoogleFonts.inter(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveValue(
                                          context,
                                          mobile: 24,
                                          tablet: 28,
                                          desktop: 32,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              if (_biometricAvailable) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Unlock with biometrics',
                                  onPressed:
                                      (ref.read(authProvider).isLoading ||
                                          _authInProgress)
                                      ? null
                                      : _authenticateWithBiometric,
                                  icon: _authInProgress
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.fingerprint_rounded),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Admin Access Portal',
                            style: GoogleFonts.inter(
                              fontSize: ResponsiveUtils.getResponsiveValue(
                                context,
                                mobile: 14,
                                tablet: 16,
                                desktop: 18,
                              ),
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          // Login form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                CustomTextField(
                                  controller: _emailController,
                                  hintText: 'Enter your email',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                   controller: _passwordController,
                                   focusNode: _passwordFocusNode,
                                   hintText: 'Enter your password',
                                   obscureText: _obscurePassword,
                                   prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  keyboardType: TextInputType.text,
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  onSubmitted: (_) =>
                                      _authenticateWithPassword(),
                                ),
                                const SizedBox(height: 24),
                                PrimaryButton(
                                  text: 'Sign In',
                                  onPressed:
                                      (_emailController.text.isNotEmpty &&
                                          _passwordController.text.length >= 6) &&
                                          !ref.read(authProvider).isLoading
                                      ? _authenticateWithPassword
                                      : null,
                                  isLoading: ref.watch(authProvider).isLoading,
                                  icon: Icons.login_rounded,
                                ),
                                if (_biometricAvailable) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed:
                                        (ref.read(authProvider).isLoading ||
                                            _authInProgress)
                                        ? null
                                        : _authenticateWithBiometric,
                                    icon: _authInProgress
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.fingerprint_rounded),
                                    label: Text(
                                      _authInProgress
                                          ? 'Authenticating…'
                                          : 'Use Biometric',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Secure admin access for library management',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
