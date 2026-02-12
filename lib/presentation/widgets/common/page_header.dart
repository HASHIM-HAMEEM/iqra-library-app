import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actions,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = GoRouter.of(context).canPop();
    final effectiveShowBack = showBack && (onBack != null || canPop);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 24,
        left: ResponsiveUtils.isMobile(context) ? 4 : 0,
        right: ResponsiveUtils.isMobile(context) ? 4 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (effectiveShowBack) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack ?? () => context.pop(),
                  borderRadius: AppRadius.borderMd,
                  hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      borderRadius: AppRadius.borderMd,
                      color: theme.colorScheme.surface,
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[const SizedBox(width: 16), ...actions!],
        ],
      ),
    );
  }
}
