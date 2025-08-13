import 'package:flutter/material.dart';
// Release builds: avoid importing ui we don't need
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/core/services/connectivity_service.dart';
import 'package:library_registration_app/core/utils/telemetry_service.dart';
import 'package:library_registration_app/presentation/widgets/common/diagnostics_overlay.dart';
import 'package:library_registration_app/core/routing/app_router.dart';
import 'package:library_registration_app/core/theme/app_theme.dart';
import 'package:library_registration_app/presentation/providers/database_provider.dart';
import 'package:library_registration_app/presentation/providers/ui/ui_state_provider.dart';
import 'package:library_registration_app/presentation/pages/splash/splash_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

 final appInitProvider = FutureProvider<void>((ref) async {
  final settingsService = ref.read(appSettingsDaoProvider);
  String? themePref;
  try {
    themePref = await settingsService
        .getStringSetting('theme_mode')
        .timeout(const Duration(milliseconds: 1200));
  } catch (_) {
    themePref = null;
  }
  final mode = switch (themePref) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  // Persist robustly to UI state before any UI builds
  ref.read(themeModeProvider.notifier).state = mode;
});

// Provider to manage splash screen timing
final splashHoldProvider = FutureProvider<void>((ref) async {
  // Wait for app initialization
  await ref.watch(appInitProvider.future);
  // Additional splash screen delay
  await Future<void>.delayed(const Duration(milliseconds: 1200));
});
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prefer the highest refresh rate available on Android devices (e.g., 120Hz),
  // and gracefully no-op on other platforms.
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
  } catch (e, st) {
    TelemetryService.instance.captureException(e, st, feature: 'display_mode');
  }
  // Initialize Supabase if config provided
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: AppConfig.developerMode,
      );
    } catch (e, st) {
      TelemetryService.instance.captureException(e, st, feature: 'supabase_init');
    }
  }
  
  // Initialize connectivity service
  try {
    await ConnectivityService.instance.initialize();
  } catch (e, st) {
    TelemetryService.instance.captureException(e, st, feature: 'connectivity_init');
  }
   // Global error handling
   FlutterError.onError = (FlutterErrorDetails details) {
     FlutterError.presentError(details);
     TelemetryService.instance.captureException(
       details.exception,
       details.stack ?? StackTrace.current,
       feature: 'flutter_framework',
       context: {
         'library': details.library ?? 'flutter',
         'context': details.context?.toDescription() ?? 'n/a',
       },
     );
   };
  runApp(const ProviderScope(child: LibraryRegistrationApp()));
 }

class LibraryRegistrationApp extends ConsumerWidget {
  const LibraryRegistrationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(splashHoldProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    if (boot.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SplashPage(),
      );
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Wrap in error boundary to avoid white screens
        final safeChild = _AppErrorBoundary(child: child);
        final theme = Theme.of(context);
        final brightness = theme.brightness;
        final navColor = theme.colorScheme.surface;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              brightness == Brightness.dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: navColor,
          systemNavigationBarIconBrightness:
              brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1).clamp(0.8, 1.2),
              ),
            ),
            // Fill background across ultra-wide tablets to avoid black side edges.
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Stack(
                children: [
                  safeChild,
                  if (AppConfig.developerMode)
                    DiagnosticsOverlay(
                      logFeed: TelemetryService.instance.logFeed,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple error boundary widget that shows a friendly fallback UI.
class _AppErrorBoundary extends StatefulWidget {
  const _AppErrorBoundary({required this.child});
  final Widget? child;
  @override
  State<_AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<_AppErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    ErrorWidget.builder = (FlutterErrorDetails details) {
      TelemetryService.instance.captureException(
        details.exception,
        details.stack ?? StackTrace.current,
        feature: 'error_widget',
      );
      return _FriendlyErrorView(
        onRetry: () => setState(() => _error = null),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _FriendlyErrorView(onRetry: () => setState(() => _error = null));
    }
    return widget.child ?? const SizedBox.shrink();
  }
}

class _FriendlyErrorView extends StatelessWidget {
  const _FriendlyErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Something went wrong. Please try again.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
