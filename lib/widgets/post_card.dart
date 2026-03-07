import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';
import 'content_widgets.dart';
import 'content_preview.dart';
import 'comment_content.dart';
import 'article_summary_widget.dart';

class PostCard extends StatelessWidget {
  final RedditPost post;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  String _truncateToWords(String text, int wordLimit) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= wordLimit) {
      return text;
    }
    return '${words.take(wordLimit).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: colors.surfaceColor,
        // Jony Ive: Remove borders, use whitespace for separation
        margin: const EdgeInsets.only(bottom: AppTheme.spacing2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing4,
            vertical: AppTheme.spacing5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metadata with summary button
              Row(
                children: [
                  Expanded(
                    child: ContentWidgets.postMetadata(
                      context: context,
                      subreddit: post.subreddit,
                      author: post.author,
                      timeAgo: FormatUtils.formatTime(post.created),
                    ),
                  ),
                  if (UrlUtils.canSummarize(post.url))
                    IconButton(
                      icon: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      onPressed: () {
                        ArticleSummaryWidget.showSummary(
                          context: context,
                          url: post.url!,
                          title: post.title,
                        );
                      },
                      tooltip: 'Summarize article',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing2),

              // Title
              Text(
                post.title,
                style: colors.theme.textTheme.titleLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Content preview based on type
              const SizedBox(height: AppTheme.spacing3),
              ContentPreview(post: post),

              // Self text preview with markdown support
              if (post.selftext != null && post.selftext!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing2),
                CommentContent(
                  content: _truncateToWords(post.selftext!, 50),
                  textStyle: colors.theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacing3),

              // Engagement metrics
              ContentWidgets.engagementMetrics(
                context: context,
                score: post.score,
                commentCount: post.numComments,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
