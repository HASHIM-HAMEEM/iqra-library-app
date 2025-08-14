import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Removed google_fonts dependency at runtime to avoid network font fetching

// Helper class to provide fallback fonts when Google Fonts fail to load
class SafeGoogleFonts {
  // Provide a safe, offline text style. Do not call GoogleFonts at runtime.
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      // Let platform default (Roboto/Android, SF Pro/iOS)
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme interTextTheme([TextTheme? textTheme]) {
    // Return given text theme or default
    return textTheme ?? const TextTheme();
  }
}

class AppTheme {
  // ChatGPT-inspired color palette
  static const Color _primaryGreen = Color(0xFF10A37F);
  static const Color _darkSidebar = Color(0xFF171717);
  static const Color _lightGray = Color(0xFFF7F7F8);
  static const Color _mediumGray = Color(0xFFECECF1);
  static const Color _textDark = Color(0xFF2D333A);
  static const Color _textLight = Color(0xFF6B7280);
  static const Color _borderLight = Color(0xFFD1D5DB);
  static const Color _errorRed = Color(0xFFEF4444);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _successGreen = Color(0xFF10B981);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _primaryGreen,
        secondary: _primaryGreen,
        error: _errorRed,
        onSecondary: Colors.white,
        onSurface: _textDark,
        outline: _borderLight,
        surfaceContainerHighest: _mediumGray,
        onSurfaceVariant: _textLight,
      ),
      textTheme: SafeGoogleFonts.interTextTheme().copyWith(
        displayLarge: SafeGoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _textDark,
          letterSpacing: -0.5,
        ),
        displayMedium: SafeGoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: _textDark,
          letterSpacing: -0.25,
        ),
        displaySmall: SafeGoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        headlineLarge: SafeGoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        headlineMedium: SafeGoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        headlineSmall: SafeGoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        titleLarge: SafeGoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        titleMedium: SafeGoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _textDark,
        ),
        titleSmall: SafeGoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _textDark,
        ),
        bodyLarge: SafeGoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _textDark,
        ),
        bodyMedium: SafeGoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _textDark,
        ),
        bodySmall: SafeGoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: _textLight,
        ),
        labelLarge: SafeGoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _textDark,
        ),
        labelMedium: SafeGoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _textDark,
        ),
        labelSmall: SafeGoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _textLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: _textDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
       titleTextStyle: SafeGoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textDark,
          side: const BorderSide(color: _borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: SafeGoogleFonts.inter(fontSize: 14, color: _textLight),
        labelStyle: SafeGoogleFonts.inter(fontSize: 14, color: _textLight),
      ),
      dividerTheme: const DividerThemeData(
        color: _borderLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: _primaryGreen,
        secondary: _primaryGreen,
        surface: _darkSidebar,
        error: _errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        outline: Color(0xFF374151),
        surfaceContainerHighest: Color(0xFF2D2D2D),
        onSurfaceVariant: Color(0xFF9CA3AF),
      ),
      textTheme: SafeGoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: SafeGoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            displayMedium: SafeGoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.25,
            ),
            displaySmall: SafeGoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            headlineLarge: SafeGoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            headlineMedium: SafeGoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            headlineSmall: SafeGoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            titleLarge: SafeGoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            titleMedium: SafeGoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            titleSmall: SafeGoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            bodyLarge: SafeGoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            bodyMedium: SafeGoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            bodySmall: SafeGoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
            labelLarge: SafeGoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            labelMedium: SafeGoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            labelSmall: SafeGoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSidebar,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: _darkSidebar,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: SafeGoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSidebar,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF374151)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
           textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF374151)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
           textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           textStyle: SafeGoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: SafeGoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
        labelStyle: SafeGoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF374151),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Custom colors for specific use cases
  static const Color successColor = _successGreen;
  static const Color warningColor = _warningOrange;
  static const Color errorColor = _errorRed;
  static const Color primaryGreen = _primaryGreen;
  static const Color darkSidebar = _darkSidebar;
  static const Color lightBackground = _lightGray;
}
