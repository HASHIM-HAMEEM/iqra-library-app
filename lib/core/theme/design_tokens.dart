import 'package:flutter/material.dart';

/// Centralized design tokens for consistent UI across the app.
///
/// Use these instead of inline literal values for border radius,
/// animation durations, and content width constraints.

// ---------------------------------------------------------------------------
// Border radius
// ---------------------------------------------------------------------------
class AppRadius {
  AppRadius._();

  /// Tiny – progress bars, small dividers (4 px)
  static const double xs = 4;

  /// Small – inputs, tooltips, icon containers (8 px)
  static const double sm = 8;

  /// Medium – cards, buttons, nav items (12 px)
  static const double md = 12;

  /// Large – data tables, section containers (16 px)
  static const double lg = 16;

  /// Extra-large – search fields, filter chips, hero cards (24 px)
  static const double xl = 24;

  /// Pill / fully-rounded – bottom nav, FAB, status badges (100 px)
  static const double pill = 100;

  // Convenience BorderRadius getters
  static BorderRadius get borderXs => BorderRadius.circular(xs);
  static BorderRadius get borderSm => BorderRadius.circular(sm);
  static BorderRadius get borderMd => BorderRadius.circular(md);
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  static BorderRadius get borderPill => BorderRadius.circular(pill);
}

// ---------------------------------------------------------------------------
// Animation durations
// ---------------------------------------------------------------------------
class AppDurations {
  AppDurations._();

  /// Fast micro-interactions (200 ms)
  static const Duration fast = Duration(milliseconds: 200);

  /// Standard transitions (300 ms)
  static const Duration normal = Duration(milliseconds: 300);

  /// Emphasis / slow reveals (500 ms)
  static const Duration slow = Duration(milliseconds: 500);
}
