import 'package:flutter/material.dart';

class CompactStatTile extends StatelessWidget {
  const CompactStatTile({
    required this.icon, required this.color, required this.label, required this.value, super.key,
    this.deltaPercent,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final double? deltaPercent; // positive => up, negative => down

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDelta = deltaPercent != null;
    final percent = deltaPercent ?? 0;
    final isUp = percent > 0;
    final isDown = percent < 0;
    final deltaColor = isUp
        ? const Color(0xFF10B981) // green 500
        : (isDown
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasDelta) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp
                      ? Icons.arrow_upward_rounded
                      : (isDown
                            ? Icons.arrow_downward_rounded
                            : Icons.remove_rounded),
                  size: 16,
                  color: deltaColor,
                ),
                const SizedBox(width: 2),
                Text(
                  _formatPercent(percent),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatPercent(double p) {
    // p is in [-1, 1] range for -100%..+100% or >1 for >100%
    final sign = p > 0 ? '+' : '';
    final abs = (p * 100).abs();
    final digits = abs >= 100 ? 0 : (abs >= 10 ? 1 : 1);
    return '$sign${abs.toStringAsFixed(digits)}%';
  }
}
