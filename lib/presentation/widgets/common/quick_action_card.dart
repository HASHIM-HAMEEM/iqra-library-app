import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/presentation/widgets/common/app_card.dart';

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
    this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.primary;

    return AppCard(
          onTap: onTap,
          padding: EdgeInsets.all(
            ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12,
              tablet: 16,
              desktop: 20,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 10,
                    tablet: 12,
                    desktop: 14,
                  ),
                ),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: actionColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  icon,
                  color: actionColor,
                  size: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 18,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 150.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 400.ms,
          delay: 150.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: 150.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
