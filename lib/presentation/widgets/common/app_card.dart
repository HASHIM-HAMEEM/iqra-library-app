import 'package:flutter/material.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.margin,
    this.padding = const EdgeInsets.all(16),
  });

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = widget.onTap != null;

    final card = MouseRegion(
      onEnter: isInteractive ? (_) => setState(() => _hovered = true) : null,
      onExit: isInteractive ? (_) => setState(() => _hovered = false) : null,
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.borderLg,
          border: Border.all(
            color: _hovered
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant,
            width: _hovered ? 1.0 : 0.8,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (!isInteractive) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.borderLg,
        hoverColor: Colors.transparent,
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}
