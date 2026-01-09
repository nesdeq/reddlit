import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

/// Loading states, empty states, and video player states
class LoadingWidgets {
  const LoadingWidgets._(); // Private constructor to prevent instantiation
  /// Standard loading indicator with accent color
  static Widget loadingIndicator(BuildContext context) {
    final colors = ThemeHelper(context);
    return Center(
      child: CircularProgressIndicator(
        color: colors.accentColor,
      ),
    );
  }

  /// Loading indicator with padding
  static Widget loadingIndicatorPadded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing6),
      child: loadingIndicator(context),
    );
  }

  /// Empty state message
  static Widget emptyState(BuildContext context, String message) {
    final colors = ThemeHelper(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing6),
      child: Center(
        child: Text(
          message,
          style: colors.theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Video player error state
  static Widget videoError(BuildContext context) {
    final colors = ThemeHelper(context);
    return _videoStateContainer(
      context,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: colors.textTertiary,
            size: 48,
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            'Failed to load video',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Video player loading state
  static Widget videoLoading(BuildContext context) {
    final colors = ThemeHelper(context);
    return _videoStateContainer(
      context,
      child: CircularProgressIndicator(
        color: colors.accentColor,
      ),
    );
  }

  /// Internal helper for video state containers
  static Widget _videoStateContainer(BuildContext context, {required Widget child}) {
    final colors = ThemeHelper(context);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colors.dividerColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Center(child: child),
    );
  }
}
