import 'package:material_ui/material_ui.dart';
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

  /// Option row for selection sheets; a tap gives a selection haptic tick.
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
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colors.accentColor)
          : null,
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

  /// Bottom-sheet list of (value, label) options, optionally titled. Pops on tap.
  static void showTitledSelection({
    required BuildContext context,
    String? title,
    required List<(String, String)> options,
    required bool Function(String value) isSelected,
    required ValueChanged<String> onSelected,
  }) {
    final colors = ThemeHelper(context);
    showBottomSheetModal(
      context: context,
      children: [
        if (title != null) ...[
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
        ],
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
