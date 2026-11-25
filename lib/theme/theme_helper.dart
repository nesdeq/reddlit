import 'package:material_ui/material_ui.dart';
import 'app_theme.dart';

/// Theme-aware colors for the current brightness.
class ThemeHelper {
  final BuildContext context;
  final bool isDark;

  ThemeHelper(this.context) : isDark = Theme.of(context).brightness == Brightness.dark;

  Color get backgroundColor => isDark ? AppTheme.darkBackground : AppTheme.background;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get accentColor => isDark ? AppTheme.darkAccent : AppTheme.accent;
  Color get accentSoftColor => isDark ? AppTheme.darkAccentSoft : AppTheme.accentSoft;
  Color get onAccentColor => isDark ? AppTheme.darkOnAccent : AppTheme.onAccent;
  Color get dividerColor => isDark ? AppTheme.darkDivider : AppTheme.divider;
  Color get threadLineColor => isDark ? AppTheme.darkThreadLine : AppTheme.threadLine;
  Color get textPrimary => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSecondary => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textTertiary => isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;
  Color get errorColor => isDark ? AppTheme.darkError : AppTheme.error;
  Color get successColor => isDark ? AppTheme.darkSuccess : AppTheme.success;
  Color get warningColor => isDark ? AppTheme.darkWarning : AppTheme.warning;

  ThemeData get theme => Theme.of(context);
}
