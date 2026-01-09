import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../constants/app_constants.dart';

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

  /// List tile for selection options (used in sort dialogs, etc.)
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
      onTap: onTap,
    );
  }

  /// Show default subreddit selection modal
  static void showDefaultSubredditModal({
    required BuildContext context,
    required String currentDefault,
    required Function(String value) onSelected,
  }) {
    final colors = ThemeHelper(context);
    showBottomSheetModal(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Text(
            'Default Subreddit',
            style: colors.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        ...AppConstants.defaultSubredditOptions.map((option) {
          final (value, label) = option;
          return selectionListTile(
            context: context,
            label: label,
            isSelected: currentDefault == value,
            onTap: () => onSelected(value),
          );
        }),
      ],
    );
  }
}
