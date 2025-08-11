import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isLargeMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 360 && width < mobileBreakpoint;
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return isSmallMobile(context)
          ? const EdgeInsets.all(16)
          : const EdgeInsets.all(20);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(32);
    } else {
      return const EdgeInsets.all(48);
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return isPortrait(context) ? 2 : 3;
    } else if (isTablet(context)) {
      return isPortrait(context) ? 3 : 4;
    } else {
      return 4;
    }
  }

  static double getGridChildAspectRatio(BuildContext context) {
    if (isMobile(context)) {
      return isPortrait(context) ? 1.2 : 1.5;
    } else if (isTablet(context)) {
      return 1.3;
    } else {
      return 1.4;
    }
  }

  static int getStatsCardsPerRow(BuildContext context) {
    if (isMobile(context)) {
      return isPortrait(context) ? 1 : 3;
    } else if (isTablet(context)) {
      return 3;
    } else {
      return 3;
    }
  }

  static double getFontSize(BuildContext context, double baseFontSize) {
    if (isSmallMobile(context)) {
      return baseFontSize * 0.9;
    } else if (isMobile(context)) {
      return baseFontSize;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  static double getIconSize(BuildContext context, double baseIconSize) {
    if (isSmallMobile(context)) {
      return baseIconSize * 0.9;
    } else if (isMobile(context)) {
      return baseIconSize;
    } else if (isTablet(context)) {
      return baseIconSize * 1.1;
    } else {
      return baseIconSize * 1.2;
    }
  }

  static double getButtonHeight(BuildContext context) {
    if (isSmallMobile(context)) {
      return 48;
    } else if (isMobile(context)) {
      return 56;
    } else {
      return 60;
    }
  }

  static double getCardElevation(BuildContext context) {
    if (isMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 4;
    } else {
      return 6;
    }
  }

  static BorderRadius getCardBorderRadius(BuildContext context) {
    if (isMobile(context)) {
      return BorderRadius.circular(12);
    } else if (isTablet(context)) {
      return BorderRadius.circular(16);
    } else {
      return BorderRadius.circular(20);
    }
  }

  static double getMaxContentWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 1200;
    } else if (isTablet(context)) {
      // Allow wider content on tablets in landscape so the UI doesn't look "shrunk".
      return isLandscape(context) ? 1000 : 800;
    } else {
      return double.infinity;
    }
  }

  static double getResponsiveValue(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isDesktop(context)) {
      return desktop;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return mobile;
    }
  }

  static Widget responsiveBuilder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
}

class ResponsiveWidget extends StatelessWidget {
  const ResponsiveWidget({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return ResponsiveUtils.responsiveBuilder(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
