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

  const CommentTile({super.key, required this.comment, this.onAuthorTap});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isCollapsed = false;

  /// Computed on first access — initState for every tile would be O(n²)
  /// across a deep tree, and the count is only ever rendered when the
  /// tile is collapsed.
  late final int _totalReplies = _countTotalReplies(widget.comment);

  /// Lazily created so we can dispose it. Kept alive across rebuilds because
  /// RichText caches recognizers and swapping them mid-flight breaks the
  /// gesture arena.
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

    return Container(
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
          AppTheme.spacing3,
          AppTheme.spacing4,
          AppTheme.spacing3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only the header folds the thread. Body stays interactive
            // (links, text selection) — no accidental collapses.
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
                                comment: reply,
                                onAuthorTap: widget.onAuthorTap,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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
