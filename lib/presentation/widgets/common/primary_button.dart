import 'package:flutter/material.dart';
import 'package:library_registration_app/core/theme/app_theme.dart';
import 'package:library_registration_app/core/utils/responsive_utils.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.enabled = true,
    this.child,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool enabled;
  final Widget? child;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _resetAnimation();
  }

  void _onTapCancel() {
    _resetAnimation();
  }

  void _resetAnimation() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  bool get _isInteractive =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).primaryColor;
    final textColor =
        widget.textColor ?? Theme.of(context).colorScheme.onPrimary;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              onTap: _isInteractive ? widget.onPressed : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.width ?? double.infinity,
                height:
                    widget.height ??
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 48,
                      tablet: 56,
                      desktop: 64,
                    ),
                padding:
                    widget.padding ??
                    EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                      vertical: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 12,
                        tablet: 16,
                        desktop: 20,
                      ),
                    ),
                decoration: BoxDecoration(
                  gradient: _isInteractive
                      ? LinearGradient(
                          colors: [
                            backgroundColor,
                            backgroundColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _isInteractive
                      ? null
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(16),
                  boxShadow: _isInteractive && !_isPressed
                      ? [
                          BoxShadow(
                            color: backgroundColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: backgroundColor.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child:
                    widget.child ??
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoading) ...[
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: _isInteractive
                                ? textColor
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.38),
                            size: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 18,
                              tablet: 20,
                              desktop: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Flexible(
                          child: Text(
                            widget.isLoading ? 'Loading...' : widget.text,
                            style: SafeGoogleFonts.inter(
                              fontSize: ResponsiveUtils.getResponsiveValue(
                                context,
                                mobile: 14,
                                tablet: 16,
                                desktop: 18,
                              ),
                              fontWeight: FontWeight.w600,
                              color: _isInteractive
                                  ? textColor
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.38),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.enabled = true,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      backgroundColor: Colors.transparent,
      textColor: textColor ?? Theme.of(context).primaryColor,
      width: width,
      height: height,
      padding: padding,
      borderRadius: borderRadius,
      enabled: enabled,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 56,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? (borderColor ?? Theme.of(context).primaryColor)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(
                icon,
                color: enabled
                    ? (textColor ?? Theme.of(context).primaryColor)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                isLoading ? 'Loading...' : text,
                style: SafeGoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (textColor ?? Theme.of(context).primaryColor)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
