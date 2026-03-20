import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../services/reddit_service.dart';
import '../widgets/comment_tile.dart';
import '../widgets/comment_content.dart';
import '../widgets/content_preview.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/content_widgets.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/article_summary_widget.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';
import '../utils/navigation_helper.dart';
import '../constants/sort_constants.dart';

class PostDetailScreen extends StatefulWidget {
  final RedditPost post;

  const PostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final RedditService _redditService = RedditService();
  List<RedditComment> _comments = [];
  bool _isLoading = false;
  String _commentSort = SortConstants.confidence; // 'confidence' = Best on Reddit

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await _redditService.getComments(
        widget.post.subreddit,
        widget.post.id,
        sort: _commentSort,
      );

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeCommentSort(String sort) {
    setState(() {
      _commentSort = sort;
      _comments = [];
    });
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (UrlUtils.canSummarize(widget.post.url))
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () {
                ArticleSummaryWidget.showSummary(
                  context: context,
                  url: widget.post.url!,
                  title: widget.post.title,
                );
              },
              tooltip: 'Summarize article',
            ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => SortDialogs.showCommentSortModal(
              context: context,
              currentSort: _commentSort,
              onSortChanged: _changeCommentSort,
            ),
            tooltip: 'Sort comments',
          ),
          const SizedBox(width: AppTheme.spacing1),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadComments,
        color: colors.accentColor,
        child: ListView(
        children: [
          // Post content
          Container(
            color: colors.surfaceColor,
            padding: const EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata
                ContentWidgets.postMetadata(
                  context: context,
                  subreddit: widget.post.subreddit,
                  author: widget.post.author,
                  timeAgo: FormatUtils.formatTime(widget.post.created),
                  onSubredditTap: () => NavigationHelper.navigateToSubreddit(context, widget.post.subreddit),
                  onAuthorTap: () => NavigationHelper.navigateToUser(context, widget.post.author),
                ),
                const SizedBox(height: AppTheme.spacing3),

                // Title
                Text(
                  widget.post.title,
                  style: colors.theme.textTheme.displayMedium,
                ),

                // Content preview (images, videos, etc.)
                const SizedBox(height: AppTheme.spacing4),
                ContentPreview(post: widget.post, isCompact: false),

                // Self text - with smart image rendering
                if (widget.post.selftext != null &&
                    widget.post.selftext!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  CommentContent(
                    content: widget.post.selftext!,
                    textStyle: colors.theme.textTheme.bodyLarge,
                  ),
                ],

                const SizedBox(height: AppTheme.spacing4),

                // Engagement metrics
                ContentWidgets.engagementMetrics(
                  context: context,
                  score: widget.post.score,
                  commentCount: widget.post.numComments,
                  iconSize: 18,
                ),
              ],
            ),
          ),

          // Jony Ive: Remove divider, use whitespace
          const SizedBox(height: AppTheme.spacing4),

          // Comments header - simplified
          if (_comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing4,
                AppTheme.spacing3,
                AppTheme.spacing4,
                AppTheme.spacing3,
              ),
              child: Text(
                'Comments',
                style: colors.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
              ),
            ),

          // Comments
          if (_isLoading && _comments.isEmpty)
            LoadingWidgets.loadingIndicatorPadded(context)
          else if (_comments.isEmpty)
            LoadingWidgets.emptyState(context, 'No comments yet')
          else
            ..._comments.map(
              (comment) => CommentTile(
                comment: comment,
                onAuthorTap: (username) => NavigationHelper.navigateToUser(context, username),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
