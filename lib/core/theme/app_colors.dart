import 'package:flutter/material.dart';
import 'package:library_registration_app/core/theme/app_theme.dart' show AppTheme;

/// Single source of truth for semantic colour constants used across the app.
///
/// These are used both directly in widget code (e.g. status badges) and by
/// [AppTheme] when building [ThemeData]. Do **not** define inline
/// `Color(0xFF...)` literals elsewhere — import this file instead.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Status / semantic colours  (most-referenced across the codebase)
  // ---------------------------------------------------------------------------

  /// Success indicators, active badges, positive stat tiles.
  static const Color success = Color(0xFF10B981);

  /// Warning banners, pending states, amber highlights.
  static const Color warning = Color(0xFFF59E0B);

  /// Error messages, destructive actions, expired badges.
  static const Color error = Color(0xFFEF4444);

  /// Informational highlights, links, login activity.
  static const Color info = Color(0xFF3B82F6);

  /// Accent purple used in quick-action cards & charts.
  static const Color purple = Color(0xFF8B5CF6);

  // ---------------------------------------------------------------------------
  // Brand / primary palette  (used by AppTheme for ColorScheme)
  // ---------------------------------------------------------------------------

  /// ChatGPT-inspired primary green.
  static const Color primaryGreen = Color(0xFF10A37F);

  /// Dark sidebar / scaffold background for dark mode.
  static const Color darkSidebar = Color(0xFF171717);

  /// Light grey surface for light mode backgrounds.
  static const Color lightBackground = Color(0xFFF7F7F8);

  /// Medium grey used for surface container highlights.
  static const Color mediumGray = Color(0xFFECECF1);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Primary text colour in light mode.
  static const Color textDark = Color(0xFF2D333A);

  /// Secondary / muted text colour in light mode.
  static const Color textLight = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Borders
  // ---------------------------------------------------------------------------

  /// Default border colour in light mode.
  static const Color borderLight = Color(0xFFD1D5DB);

  // ---------------------------------------------------------------------------
  // Dark-mode specific
  // ---------------------------------------------------------------------------

  /// Border colour in dark mode.
  static const Color darkBorder = Color(0xFF374151);

  /// Surface container highlight in dark mode.
  static const Color darkSurface = Color(0xFF2D2D2D);

  /// Muted text in dark mode.
  static const Color darkMutedText = Color(0xFF9CA3AF);
}
