import 'package:flutter/material.dart';
import '../models/reddit_comment.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../constants/app_constants.dart';
import 'comment_content.dart';

class CommentTile extends StatefulWidget {
  final RedditComment comment;
  final Function(String)? onAuthorTap; // Changed to accept username parameter

  const CommentTile({
    super.key,
    required this.comment,
    this.onAuthorTap,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isCollapsed = false;
  late final int _totalReplies;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.comment.depth >= AppConstants.commentAutoCollapseDepth;
    _totalReplies = _countTotalReplies(widget.comment);
  }

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    // Jony Ive principle: Simplicity through constraint
    // Only indent first levels fully, then use subtle visual cues
    final shouldIndent = widget.comment.depth <= AppConstants.commentMaxIndentDepth;
    final indentation = shouldIndent ? widget.comment.depth * 12.0 : (AppConstants.commentMaxIndentDepth * 12.0);

    // Thread line colors get progressively lighter at deeper levels
    final threadLineOpacity = widget.comment.depth > 0
        ? (AppConstants.threadLineBaseOpacity - (widget.comment.depth * AppConstants.threadLineOpacityDecrement))
            .clamp(AppConstants.threadLineMinOpacity, AppConstants.threadLineBaseOpacity)
        : AppConstants.threadLineBaseOpacity;
    final threadColor = colors.dividerColor.withValues(alpha: threadLineOpacity);

    return GestureDetector(
      onTap: _toggleCollapse, // Any comment can be collapsed, just like Reddit
      child: Container(
        margin: EdgeInsets.only(left: indentation),
        decoration: BoxDecoration(
          // Jony Ive: Simplified borders - only thread line, no bottom border
          border: widget.comment.depth > 0
              ? Border(
                  left: BorderSide(
                    color: threadColor,
                    width: 1.5, // Slightly thinner for subtlety
                  ),
                )
              : null,
        ),
        child: Padding(
          // Jony Ive: More generous padding for breathing room
          padding: const EdgeInsets.all(AppTheme.spacing3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author and metadata
              Row(
                children: [
                  // Depth indicator for deep nesting (Jony Ive: functional minimalism)
                  if (widget.comment.depth > AppConstants.commentMaxIndentDepth) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.dividerColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.comment.depth}',
                        style: colors.theme.textTheme.labelMedium?.copyWith(
                              color: colors.textTertiary,
                              fontSize: 11,
                            ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing2),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: AppTheme.spacing2,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onAuthorTap?.call(widget.comment.author), // FIX: Pass the actual comment's author
                          child: Text(
                            'u/${widget.comment.author}',
                            style: colors.theme.textTheme.labelMedium?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '•',
                          style: colors.theme.textTheme.labelMedium?.copyWith(
                                color: colors.textTertiary,
                              ),
                        ),
                        Text(
                          '${FormatUtils.formatNumber(widget.comment.score)} pts',
                          style: colors.theme.textTheme.labelMedium,
                        ),
                        Text(
                          '•',
                          style: colors.theme.textTheme.labelMedium?.copyWith(
                                color: colors.textTertiary,
                              ),
                        ),
                        Text(
                          FormatUtils.formatTime(widget.comment.created),
                          style: colors.theme.textTheme.labelMedium?.copyWith(
                                color: colors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Jony Ive: Clean, consistent end-of-line indicator
                  // Show for any comment with replies, or if collapsed
                  if (widget.comment.replies.isNotEmpty || _isCollapsed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show count when collapsed
                        if (_isCollapsed) ...[
                          Text(
                            '$_totalReplies',
                            style: colors.theme.textTheme.labelMedium?.copyWith(
                                  color: colors.textTertiary,
                                  fontWeight: FontWeight.w700, // Bold, like you asked
                                ),
                          ),
                          const SizedBox(width: 2),
                        ],
                        Icon(
                          _isCollapsed ? Icons.chevron_right : Icons.expand_more,
                          size: 18,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                ],
              ),

              // Only show body and replies if not collapsed
              if (!_isCollapsed) ...[
                const SizedBox(height: AppTheme.spacing2),

                // Comment body - with smart image rendering
                CommentContent(content: widget.comment.body),

                // Replies - no additional spacing, let thread lines define hierarchy
                if (widget.comment.replies.isNotEmpty)
                  ...widget.comment.replies.map(
                    (reply) => CommentTile(
                      comment: reply,
                      onAuthorTap: widget.onAuthorTap, // Pass the same callback, each comment will use its own author
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
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
