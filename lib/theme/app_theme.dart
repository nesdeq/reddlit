import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AppTheme {
  static const String uiFont = 'Source Sans 3';
  static const String readingFont = 'Source Serif 4';

  /// Bundled fonts as (name, license asset), for the license registry.
  static const List<(String, String)> fontLicenses = [
    (uiFont, 'assets/fonts/OFL-SourceSans3.txt'),
    (readingFont, 'assets/fonts/OFL-SourceSerif4.txt'),
  ];

  /// WCAG 2.2 SC 1.4.12 line height for running text.
  static const double readingLineHeight = 1.5;

  /// [style] set in the reading typeface, for long-form text.
  static TextStyle reading(TextStyle? style) => (style ?? const TextStyle())
      .copyWith(fontFamily: readingFont, height: readingLineHeight);

  // Light theme colors
  static const Color background = Color(0xFFF4F0E8);
  static const Color surface = Color(0xFFFBF9F4);
  static const Color textPrimary = Color(0xFF1F1E1B);
  static const Color textSecondary = Color(0xFF5C5A53);
  static const Color textTertiary = Color(0xFF6C6960);
  static const Color divider = Color(0xFFE3DDD0);
  static const Color threadLine = Color(0xFFC4BAA7);
  static const Color accent = Color(0xFFB8491F);
  static const Color accentSoft = Color(0xFFFCEEE4);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF4F6B3A);
  static const Color warning = Color(0xFF8A5A00);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF1C1B19);
  static const Color darkSurface = Color(0xFF262522);
  static const Color darkTextPrimary = Color(0xFFF2EEE6);
  static const Color darkTextSecondary = Color(0xFFB9B4A8);
  static const Color darkTextTertiary = Color(0xFF959084);
  static const Color darkDivider = Color(0xFF3A3833);
  static const Color darkThreadLine = Color(0xFF5A564E);
  static const Color darkAccent = Color(0xFFE58A63);
  static const Color darkAccentSoft = Color(0xFF38251C);
  static const Color darkOnAccent = Color(0xFF1C1B19);
  static const Color darkError = Color(0xFFF2857A);
  static const Color darkSuccess = Color(0xFFA3BF8A);
  static const Color darkWarning = Color(0xFFE0B25C);

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    backgroundColor: background,
    surfaceColor: surface,
    textPrimaryColor: textPrimary,
    textSecondaryColor: textSecondary,
    textTertiaryColor: textTertiary,
    accentColor: accent,
    onAccentColor: onAccent,
    dividerColor: divider,
    errorColor: error,
    overlayStyle: SystemUiOverlayStyle.dark,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    backgroundColor: darkBackground,
    surfaceColor: darkSurface,
    textPrimaryColor: darkTextPrimary,
    textSecondaryColor: darkTextSecondary,
    textTertiaryColor: darkTextTertiary,
    accentColor: darkAccent,
    onAccentColor: darkOnAccent,
    dividerColor: darkDivider,
    errorColor: darkError,
    overlayStyle: SystemUiOverlayStyle.light,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color backgroundColor,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color textTertiaryColor,
    required Color accentColor,
    required Color onAccentColor,
    required Color dividerColor,
    required Color errorColor,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: uiFont,
      // Roles not named here (containers, inverse surface) are warm neutrals derived from the accent.
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
        primary: accentColor,
        onPrimary: onAccentColor,
        secondary: accentColor,
        onSecondary: onAccentColor,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        onSurfaceVariant: textSecondaryColor,
        outline: textTertiaryColor,
        outlineVariant: dividerColor,
        error: errorColor,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: TextStyle(
          fontFamily: readingFont,
          color: textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: _buildTextTheme(textPrimaryColor, textSecondaryColor),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0,
      ),
      iconTheme: IconThemeData(
        color: textSecondaryColor,
        size: 22,
      ),
      extensions: [YoutubePlayerTheme(progressBarActiveColor: accentColor)],
    );
  }

  /// Headlines in the reading typeface; everything else inherits the UI typeface.
  static TextTheme _buildTextTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: readingFont,
        fontSize: 34, fontWeight: FontWeight.w700,
        color: primaryColor, height: 1.2,
      ),
      displayMedium: TextStyle(
        fontFamily: readingFont,
        fontSize: 28, fontWeight: FontWeight.w600,
        color: primaryColor, height: 1.2,
      ),
      titleLarge: TextStyle(
        fontFamily: readingFont,
        fontSize: 17, fontWeight: FontWeight.w600,
        color: primaryColor, height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w500,
        color: primaryColor, height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w400,
        color: primaryColor, height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400,
        color: primaryColor, height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w400,
        color: secondaryColor, height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: secondaryColor, height: 1.2,
      ),
      labelSmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
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
