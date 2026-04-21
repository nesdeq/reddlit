import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../constants/app_constants.dart';
import '../utils/haptics.dart';

/// Modal bottom sheets and selection widgets
class ModalWidgets {
  const ModalWidgets._();
  /// Modal bottom sheet with standard styling
  static Future<T?> showBottomSheetModal<T>({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colors = ThemeHelper(context);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: colors.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: AppTheme.spacing2),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
              ],
            ),
          ),
        );
      },
    );
  }

  /// List tile for selection options (used in sort dialogs, etc.).
  /// Emits a subtle haptic tick on tap — discrete selections should feel like
  /// picking something physical.
  static Widget selectionListTile({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = ThemeHelper(context);
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? colors.textPrimary : colors.textSecondary,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: colors.accentColor) : null,
      onTap: () {
        Haptics.selectionClick();
        onTap();
      },
    );
  }

  /// Show default subreddit selection modal. Pops itself before invoking
  /// [onSelected] so callers don't need to manage modal dismissal.
  static void showDefaultSubredditModal({
    required BuildContext context,
    required String currentDefault,
    required ValueChanged<String> onSelected,
  }) {
    showTitledSelection(
      context: context,
      title: 'Default Subreddit',
      options: AppConstants.defaultSubredditOptions,
      isSelected: (value) => currentDefault == value,
      onSelected: onSelected,
    );
  }

  /// Titled bottom-sheet list of (value, label) options. Pops on tap.
  static void showTitledSelection({
    required BuildContext context,
    required String title,
    required List<(String, String)> options,
    required bool Function(String value) isSelected,
    required ValueChanged<String> onSelected,
  }) {
    final colors = ThemeHelper(context);
    showBottomSheetModal(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Text(
            title,
            style: colors.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        ...options.map((option) {
          final (value, label) = option;
          return selectionListTile(
            context: context,
            label: label,
            isSelected: isSelected(value),
            onTap: () {
              Navigator.pop(context);
              onSelected(value);
            },
          );
        }),
      ],
    );
  }
}
