import 'package:flutter/material.dart';
import 'package:library_registration_app/core/theme/app_theme.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class CustomNotification {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.success,
    Duration duration = const Duration(seconds: 2),
    IconData? icon,
  }) {
    // Remove any existing notification
    hide();

    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    
    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        type: type,
        theme: theme,
        icon: icon,
        onDismiss: hide,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      hide();
    });
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final ThemeData theme;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.theme,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    final isDark = widget.theme.brightness == Brightness.dark;
    
    switch (widget.type) {
      case NotificationType.success:
        return isDark 
            ? const Color(0xFF10B981).withValues(alpha: 0.9)
            : const Color(0xFF10B981).withValues(alpha: 0.95);
      case NotificationType.error:
        return isDark 
            ? const Color(0xFFEF4444).withValues(alpha: 0.9)
            : const Color(0xFFEF4444).withValues(alpha: 0.95);
      case NotificationType.warning:
        return isDark 
            ? const Color(0xFFF59E0B).withValues(alpha: 0.9)
            : const Color(0xFFF59E0B).withValues(alpha: 0.95);
      case NotificationType.info:
        return isDark 
            ? widget.theme.colorScheme.primary.withValues(alpha: 0.9)
            : widget.theme.colorScheme.primary.withValues(alpha: 0.95);
    }
  }

  Color _getTextColor() {
    return Colors.white;
  }

  IconData _getIcon() {
    if (widget.icon != null) return widget.icon!;
    
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get keyboard height to position notification above it
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Position notification above keyboard when visible, otherwise use default position
    final bottomPosition = keyboardHeight > 0 ? keyboardHeight + 16 : 100.0;
    
    return Positioned(
      bottom: bottomPosition,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 50 * _slideAnimation.value),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIcon(),
                        color: _getTextColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: SafeGoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _getTextColor(),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: Icon(
                          Icons.close,
                          color: _getTextColor().withValues(alpha: 0.8),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}