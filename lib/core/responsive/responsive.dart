import 'package:flutter/widgets.dart';

class Breakpoints {
  static const double mobile = 600; // phones
  static const double tablet = 1024; // small/large tablets & iPads (portrait)
  static const double desktop = 1440; // large screens
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
  const Responsive({super.key, required this.mobile, this.tablet, this.desktop});
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
  const ResponsivePadding({super.key, required this.child});
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
  if (context.isDesktop) return (desktop ?? tablet ?? mobile);
  if (context.isTablet) return (tablet ?? mobile);
  return mobile;
}

class MaxWidthWrapper extends StatelessWidget {
  const MaxWidthWrapper({super.key, required this.child, this.maxWidth = 1000, this.alignment = Alignment.topCenter});
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
