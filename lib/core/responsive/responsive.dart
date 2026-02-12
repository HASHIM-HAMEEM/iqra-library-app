import 'package:flutter/widgets.dart';

// Canonical responsive module.
//
// NOTE: We still export the legacy `ResponsiveUtils` API for backward
// compatibility while the codebase migrates off of it.
export '../utils/responsive_utils.dart';

class Breakpoints {
  static const double mobile = 600; // phones
  static const double tablet = 1024; // tablets & small laptops
  static const double desktop = 1440; // large screens (wide layout tweaks)
}

enum DeviceType { mobile, tablet, desktop }

extension MediaQueryX on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get width => screenSize.width;
  double get height => screenSize.height;
  DeviceType get deviceType {
    final w = width;
    if (w < Breakpoints.mobile) return DeviceType.mobile;
    if (w < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }
  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
}

typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context);

class Responsive extends StatelessWidget {
  const Responsive({required this.mobile, super.key, this.tablet, this.desktop});
  final ResponsiveWidgetBuilder mobile;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.mobile:
        return mobile(context);
      case DeviceType.tablet:
        return (tablet ?? mobile)(context);
      case DeviceType.desktop:
        return (desktop ?? tablet ?? mobile)(context);
    }
  }
}

class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({required this.child, super.key});
  final Widget child;

  static EdgeInsets paddingFor(BuildContext context) {
    if (context.isDesktop) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (context.isTablet) return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: paddingFor(context), child: child);
  }
}

T responsiveValue<T>(BuildContext context, {required T mobile, T? tablet, T? desktop}) {
  if (context.isDesktop) return desktop ?? tablet ?? mobile;
  if (context.isTablet) return tablet ?? mobile;
  return mobile;
}

class MaxWidthWrapper extends StatelessWidget {
  const MaxWidthWrapper({required this.child, this.maxWidth = 1000, this.alignment = Alignment.topCenter, super.key});
  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
