import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Helper class to get theme-aware colors based on current brightness
/// Eliminates duplicate isDark checking code throughout the app (DRY principle)
class ThemeHelper {
  final BuildContext context;
  final bool isDark;

  ThemeHelper(this.context) : isDark = Theme.of(context).brightness == Brightness.dark;

  Color get backgroundColor => isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get accentColor => isDark ? AppTheme.darkAccent : AppTheme.accent;
  Color get dividerColor => isDark ? AppTheme.darkDivider : AppTheme.divider;
  Color get textPrimary => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSecondary => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textTertiary => isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;

  ThemeData get theme => Theme.of(context);
}
