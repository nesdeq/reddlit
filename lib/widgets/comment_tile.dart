import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  final ValueChanged<String>? onAuthorTap;
  final ValueChanged<RedditComment>? onLoadMore;

  const CommentTile({
    super.key,
    required this.comment,
    this.onAuthorTap,
    this.onLoadMore,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isCollapsed = false;
  bool _loadingMore = false;

  late final int _totalReplies = _countTotalReplies(widget.comment);

  late final TapGestureRecognizer _authorTap = TapGestureRecognizer()
    ..onTap = () => widget.onAuthorTap?.call(widget.comment.author);

  @override
  void initState() {
    super.initState();
    _isCollapsed =
        widget.comment.depth >= AppConstants.commentAutoCollapseDepth;
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

  void _handleLoadMore() {
    if (_loadingMore || widget.onLoadMore == null) return;
    Haptics.selectionClick();
    setState(() => _loadingMore = true);
    widget.onLoadMore!(widget.comment);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final comment = widget.comment;

    final shouldIndent = comment.depth <= AppConstants.commentMaxIndentDepth;
    final indentation = shouldIndent
        ? comment.depth * AppConstants.commentIndentStep
        : AppConstants.commentMaxIndentDepth * AppConstants.commentIndentStep;

    final threadColor = colors.dividerColor.withValues(
      alpha: AppConstants.threadLineOpacity,
    );

    final indented = Container(
      margin: EdgeInsets.only(
        left: indentation,
        top: comment.depth == 0 ? AppTheme.spacing1 : 0,
      ),
      decoration: BoxDecoration(
        border: comment.depth > 0
            ? Border(
                left: BorderSide(
                  color: threadColor,
                  width: AppConstants.threadLineWidth,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          comment.depth > 0 ? AppTheme.spacing3 : AppTheme.spacing4,
          AppTheme.spacing2,
          AppTheme.spacing4,
          AppTheme.spacing2,
        ),
        child: comment.isMorePlaceholder
            ? _buildMoreTile(colors)
            : _buildComment(colors),
      ),
    );

    return indented;
  }

  Widget _buildMoreTile(ThemeHelper colors) {
    final count = widget.comment.moreChildrenIds.length;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleCollapse,
          child: _buildHeader(colors),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _isCollapsed
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommentContent(content: comment.body),
                      if (comment.replies.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing1),
                        ...comment.replies.map(
                          (reply) => CommentTile(
                            key: ValueKey(reply.id),
                            comment: reply,
                            onAuthorTap: widget.onAuthorTap,
                            onLoadMore: widget.onLoadMore,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeHelper colors) {
    final comment = widget.comment;
    final label = colors.theme.textTheme.labelSmall;

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
        if (_isCollapsed && _totalReplies > 0) ...[
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
              '+$_totalReplies',
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
