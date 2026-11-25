import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import '../models/reddit_comment.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/haptics.dart';
import '../constants/app_constants.dart';
import 'comment_content.dart';
import 'content_widgets.dart';

class CommentTile extends StatefulWidget {
  final RedditComment comment;

  /// The comment a link pointed at: highlighted, and never hidden by auto-collapse.
  final String? focusedId;

  /// Author of the comment this one answers, shown where indentation has stopped.
  final String? parentAuthor;
  final ValueChanged<String>? onAuthorTap;
  final Future<void> Function(RedditComment placeholder)? onLoadMore;

  const CommentTile({
    super.key,
    required this.comment,
    this.focusedId,
    this.parentAuthor,
    this.onAuthorTap,
    this.onLoadMore,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isCollapsed = false;
  bool _loadingMore = false;

  late final TapGestureRecognizer _authorTap = TapGestureRecognizer()
    ..onTap = () => widget.onAuthorTap?.call(widget.comment.author);

  @override
  void initState() {
    super.initState();
    final focusedId = widget.focusedId;
    _isCollapsed =
        widget.comment.depth >= AppConstants.commentAutoCollapseDepth &&
        !(focusedId != null && widget.comment.contains(focusedId));
  }

  @override
  void dispose() {
    _authorTap.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    Haptics.selectionClick();
    setState(() => _isCollapsed = !_isCollapsed);
  }

  Future<void> _handleLoadMore() async {
    final onLoadMore = widget.onLoadMore;
    if (_loadingMore || onLoadMore == null) return;
    Haptics.selectionClick();
    setState(() => _loadingMore = true);
    try {
      await onLoadMore(widget.comment);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final comment = widget.comment;
    final child = comment.isMorePlaceholder
        ? _buildMoreTile(colors)
        : _buildComment(colors);

    if (comment.depth == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing4,
          AppTheme.spacing3,
          AppTheme.spacing4,
          AppTheme.spacing2,
        ),
        child: child,
      );
    }
    // Replies nest inside their parent, so each adds one step and the screen margin is never repeated.
    if (!_indents) {
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing2),
        child: child,
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spacing2),
      padding: const EdgeInsets.only(
        left: AppConstants.commentIndentStep - AppConstants.threadLineWidth,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.threadLineColor,
            width: AppConstants.threadLineWidth,
          ),
        ),
      ),
      child: child,
    );
  }

  bool get _indents =>
      widget.comment.depth <= AppConstants.commentMaxIndentDepth;

  Widget _buildMoreTile(ThemeHelper colors) {
    final count = widget.comment.replyCount;
    final label = count > 0 ? 'Load $count more replies' : 'Continue thread';
    return InkWell(
      onTap: _loadingMore ? null : _handleLoadMore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
        child: Row(
          children: [
            if (_loadingMore)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accentColor,
                ),
              )
            else
              Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: colors.accentColor,
              ),
            const SizedBox(width: AppTheme.spacing2),
            Text(
              _loadingMore ? 'Loading…' : label,
              style: colors.theme.textTheme.labelSmall?.copyWith(
                color: colors.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComment(ThemeHelper colors) {
    final comment = widget.comment;
    final parentAuthor = widget.parentAuthor;
    final own = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parentAuthor != null && !_indents)
                _buildAnswers(colors, parentAuthor),
              _buildHeader(colors),
            ],
          ),
        ),
        _collapsible(
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing2),
            child: CommentContent(content: comment.body),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.id == widget.focusedId)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: colors.accentSoftColor,
              border: Border.all(color: colors.accentColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: own,
          )
        else
          own,
        if (comment.replies.isNotEmpty)
          _collapsible(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reply in comment.replies)
                  CommentTile(
                    key: ValueKey(reply.id),
                    comment: reply,
                    focusedId: widget.focusedId,
                    parentAuthor: comment.author,
                    onAuthorTap: widget.onAuthorTap,
                    onLoadMore: widget.onLoadMore,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _collapsible(Widget child) => AnimatedSize(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topLeft,
    child: _isCollapsed ? const SizedBox(width: double.infinity) : child,
  );

  Widget _buildAnswers(ThemeHelper colors, String parentAuthor) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
    child: Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right_rounded,
          size: 14,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppTheme.spacing1),
        Flexible(
          child: Text(
            'u/$parentAuthor',
            style: colors.theme.textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _buildHeader(ThemeHelper colors) {
    final comment = widget.comment;
    final label = colors.theme.textTheme.labelSmall;
    final hiddenReplies = _isCollapsed ? _countTotalReplies(comment) : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'u/${comment.author}',
                  style: label?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: widget.onAuthorTap == null ? null : _authorTap,
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ContentWidgets.bullet(colors),
                ),
                TextSpan(
                  text: '${FormatUtils.formatNumber(comment.score)} pts',
                  style: label,
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ContentWidgets.bullet(colors),
                ),
                TextSpan(
                  text: FormatUtils.formatTime(comment.created),
                  style: label?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hiddenReplies > 0) ...[
          const SizedBox(width: AppTheme.spacing2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: colors.dividerColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              '+$hiddenReplies',
              style: label?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(width: AppTheme.spacing1),
        Icon(
          _isCollapsed
              ? Icons.chevron_right_rounded
              : Icons.expand_more_rounded,
          size: 18,
          color: colors.textTertiary,
        ),
      ],
    );
  }

  int _countTotalReplies(RedditComment comment) {
    int count = comment.replies.length;
    for (final reply in comment.replies) {
      count += _countTotalReplies(reply);
    }
    return count;
  }
}
