import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light theme colors - Jony Ive inspired: minimal, clean, focused
  static const Color primary = Color(0xFF000000);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFF007AFF);

  // Dark theme colors - soft contrast, easy on the eyes
  static const Color darkPrimary = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF1C1C1E);
  static const Color darkSurface = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA1A1A6);
  static const Color darkTextTertiary = Color(0xFF6B6B70);
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkAccent = Color(0xFF0A84FF);

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    primaryColor: primary,
    backgroundColor: background,
    surfaceColor: surface,
    textPrimaryColor: textPrimary,
    textSecondaryColor: textSecondary,
    accentColor: accent,
    dividerColor: divider,
    errorColor: const Color(0xFFFF3B30),
    overlayStyle: SystemUiOverlayStyle.dark,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    backgroundColor: darkBackground,
    surfaceColor: darkSurface,
    textPrimaryColor: darkTextPrimary,
    textSecondaryColor: darkTextSecondary,
    accentColor: darkAccent,
    dividerColor: darkDivider,
    errorColor: const Color(0xFFFF453A),
    overlayStyle: SystemUiOverlayStyle.light,
    onSurface: darkTextPrimary,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primaryColor,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color accentColor,
    required Color dividerColor,
    required Color errorColor,
    required SystemUiOverlayStyle overlayStyle,
    Color? onSurface,
  }) {
    final isLight = brightness == Brightness.light;
    final colorScheme = isLight
        ? ColorScheme.light(
            primary: primaryColor,
            secondary: accentColor,
            surface: surfaceColor,
            error: errorColor,
          )
        : ColorScheme.dark(
            primary: primaryColor,
            secondary: accentColor,
            surface: surfaceColor,
            error: errorColor,
            onSurface: onSurface ?? textPrimaryColor,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryColor,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: _buildTextTheme(textPrimaryColor, textSecondaryColor),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0,
      ),
      iconTheme: IconThemeData(
        color: textSecondaryColor,
        size: 22,
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5,
        color: primaryColor, height: 1.2,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3,
        color: primaryColor, height: 1.2,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2,
        color: primaryColor, height: 1.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2,
        color: primaryColor, height: 1.3,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.2,
        color: primaryColor, height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.1,
        color: primaryColor, height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.1,
        color: secondaryColor, height: 1.3,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.1,
        color: secondaryColor, height: 1.2,
      ),
    );
  }

  // Consistent spacing values
  static const double spacing1 = 4.0;
  static const double spacing2 = 8.0;
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 20.0;
  static const double spacing6 = 24.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
}
