import 'package:material_ui/material_ui.dart';
import '../constants/sort_constants.dart';
import 'modal_widgets.dart';

/// Sort pickers for posts and comments, listed from the SortConstants label maps.
class SortDialogs {
  const SortDialogs._();

  /// Picking Top asks for its time window before reporting.
  static void showPostSortModal({
    required BuildContext context,
    required String currentSort,
    required String? currentTopTime,
    required void Function(String sort, {String? topTime}) onSortChanged,
  }) {
    _show(context, SortConstants.postSortLabels, currentSort, (sort) {
      if (sort == SortConstants.top) {
        _show(
          context,
          SortConstants.topTimeLabels,
          currentTopTime,
          (topTime) => onSortChanged(sort, topTime: topTime),
        );
      } else {
        onSortChanged(sort);
      }
    });
  }

  static void showCommentSortModal({
    required BuildContext context,
    required String currentSort,
    required ValueChanged<String> onSortChanged,
  }) => _show(
    context,
    SortConstants.commentSortLabels,
    currentSort,
    onSortChanged,
  );

  static void _show(
    BuildContext context,
    Map<String, String> labels,
    String? current,
    ValueChanged<String> onSelected,
  ) {
    ModalWidgets.showTitledSelection(
      context: context,
      options: [for (final e in labels.entries) (e.key, e.value)],
      isSelected: (value) => value == current,
      onSelected: onSelected,
    );
  }
}
