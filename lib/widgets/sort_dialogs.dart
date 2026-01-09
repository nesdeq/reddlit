import 'package:flutter/material.dart';
import '../constants/sort_constants.dart';
import 'modal_widgets.dart';

/// Sort modal dialogs for posts and comments
class SortDialogs {
  const SortDialogs._();

  static const _postSortOptions = [
    SortConstants.hot,
    SortConstants.newSort,
    SortConstants.rising,
    SortConstants.controversial,
    SortConstants.top,
  ];

  static const _timePeriodOptions = [
    SortConstants.topHour,
    SortConstants.topDay,
    SortConstants.topWeek,
    SortConstants.topMonth,
    SortConstants.topYear,
    SortConstants.topAll,
  ];

  static const _commentSortOptions = [
    SortConstants.confidence,
    SortConstants.top,
    SortConstants.newSort,
    SortConstants.controversial,
  ];

  /// Show post sort options modal (Hot, New, Rising, Controversial, Top)
  static void showPostSortModal({
    required BuildContext context,
    required String currentSort,
    required String? currentTopTime,
    required Function(String sort, {String? topTime}) onSortChanged,
  }) {
    ModalWidgets.showBottomSheetModal(
      context: context,
      children: _postSortOptions.map((sort) {
        return ModalWidgets.selectionListTile(
          context: context,
          label: SortConstants.postSortLabels[sort]!,
          isSelected: currentSort == sort,
          onTap: () {
            Navigator.pop(context);
            if (sort == SortConstants.top) {
              showTopTimeModal(
                context: context,
                currentTopTime: currentTopTime,
                onTimeSelected: (topTime) => onSortChanged(sort, topTime: topTime),
              );
            } else {
              onSortChanged(sort);
            }
          },
        );
      }).toList(),
    );
  }

  /// Show top time period modal (Hour, Day, Week, Month, Year, All)
  static void showTopTimeModal({
    required BuildContext context,
    required String? currentTopTime,
    required Function(String topTime) onTimeSelected,
  }) {
    ModalWidgets.showBottomSheetModal(
      context: context,
      children: _timePeriodOptions.map((time) {
        return ModalWidgets.selectionListTile(
          context: context,
          label: SortConstants.topTimeLabels[time]!,
          isSelected: currentTopTime == time,
          onTap: () {
            Navigator.pop(context);
            onTimeSelected(time);
          },
        );
      }).toList(),
    );
  }

  /// Show comment sort options modal (Best, Top, New, Controversial)
  static void showCommentSortModal({
    required BuildContext context,
    required String currentSort,
    required Function(String sort) onSortChanged,
  }) {
    ModalWidgets.showBottomSheetModal(
      context: context,
      children: _commentSortOptions.map((sort) {
        return ModalWidgets.selectionListTile(
          context: context,
          label: SortConstants.commentSortLabels[sort]!,
          isSelected: currentSort == sort,
          onTap: () {
            Navigator.pop(context);
            onSortChanged(sort);
          },
        );
      }).toList(),
    );
  }
}
