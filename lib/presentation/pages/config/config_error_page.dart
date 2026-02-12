import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/core/theme/app_theme.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const ConfigErrorPage(),
    );
  }
}

class ConfigErrorPage extends StatelessWidget {
  const ConfigErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issues = AppConfig.supabaseConfigIssues;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset('IqraLogo.png'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuration Required',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'This build is missing required Supabase settings.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (issues.isNotEmpty) ...[
                    _IssueList(issues: issues),
                    const SizedBox(height: 16),
                  ],
                  const _CommandCard(
                    title: 'Run (development)',
                    command:
                        'flutter run -d chrome \\\n'
                        '  --dart-define=SUPABASE_URL=<YOUR_SUPABASE_URL> \\\n'
                        '  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>',
                  ),
                  const SizedBox(height: 12),
                  const _CommandCard(
                    title: 'Build (web release)',
                    command:
                        'flutter build web --release \\\n'
                        '  --dart-define=SUPABASE_URL=<YOUR_SUPABASE_URL> \\\n'
                        '  --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If you are seeing this on Firebase Hosting, the site was deployed '
                    'without these build defines. Rebuild and redeploy.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected issues',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.title, required this.command});

  final String title;
  final String command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Command copied to clipboard')),
              );
            },
            borderRadius: AppRadius.borderMd,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.borderMd,
              ),
              child: Text(
                command,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
