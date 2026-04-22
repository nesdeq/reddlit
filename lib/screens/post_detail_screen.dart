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

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final RedditService _redditService = RedditService();
  final ScrollController _scrollController = ScrollController();

  List<RedditComment> _tree = const [];
  bool _isLoading = false;
  String _commentSort = SortConstants.confidence;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    final cached = _redditService.peekComments(
      widget.post.subreddit,
      widget.post.id,
      sort: _commentSort,
    );
    if (cached != null) _tree = cached;
    _loadComments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadComments() async {
    final token = ++_loadToken;
    setState(() => _isLoading = _tree.isEmpty);
    try {
      final raw = await _redditService.getComments(
        widget.post.subreddit,
        widget.post.id,
        sort: _commentSort,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _tree = raw;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _isLoading = false);
    }
  }

  void _changeCommentSort(String sort) {
    setState(() {
      _commentSort = sort;
      _tree = const [];
    });
    _loadComments();
  }

  Future<void> _onMoreTap(RedditComment placeholder) async {
    final token = _loadToken;
    final fetched = await _redditService.loadMoreComments(
      linkId: 't3_${widget.post.id}',
      childIds: placeholder.moreChildrenIds,
      sort: _commentSort,
    );
    if (!mounted || token != _loadToken) return;
    final merged = _mergeMoreReplies(_tree, placeholder, fetched);
    setState(() => _tree = merged);
    _redditService.cacheExpandedComments(
      widget.post.subreddit,
      widget.post.id,
      _commentSort,
      merged,
    );
  }

  List<RedditComment> _mergeMoreReplies(
    List<RedditComment> tree,
    RedditComment placeholder,
    List<RedditComment> fetched,
  ) {
    final byParent = <String, List<RedditComment>>{};
    for (final c in fetched) {
      final pid = c.parentId ?? '';
      byParent.putIfAbsent(pid, () => []).add(c);
    }

    List<RedditComment> buildSubtree(String? parentFullname, int depth) {
      final children = byParent[parentFullname ?? ''] ?? const [];
      return children
          .map(
            (c) => c.copyWith(
              depth: depth,
              replies: buildSubtree('t1_${c.id}', depth + 1),
            ),
          )
          .toList();
    }

    final siblings = buildSubtree(placeholder.parentId, placeholder.depth);

    List<RedditComment> replaceIn(List<RedditComment> list) {
      final result = <RedditComment>[];
      for (final c in list) {
        if (c.isMorePlaceholder && c.id == placeholder.id) {
          result.addAll(siblings);
        } else if (c.replies.isNotEmpty) {
          result.add(c.copyWith(replies: replaceIn(c.replies)));
        } else {
          result.add(c);
        }
      }
      return result;
    }

    return replaceIn(tree);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final tree = _tree;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _scrollToTop,
          child: const Text('Post'),
        ),
        actions: [
          if (UrlUtils.canSummarize(widget.post.url))
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => ArticleSummaryWidget.showSummary(
                context: context,
                url: widget.post.url!,
                title: widget.post.title,
              ),
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
          controller: _scrollController,
          children: [
            Container(
              color: colors.surfaceColor,
              padding: const EdgeInsets.all(AppTheme.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentWidgets.postMetadata(
                    context: context,
                    subreddit: widget.post.subreddit,
                    author: widget.post.author,
                    timeAgo: FormatUtils.formatTime(widget.post.created),
                    onSubredditTap: () => NavigationHelper.navigateToSubreddit(
                      context,
                      widget.post.subreddit,
                    ),
                    onAuthorTap: () => NavigationHelper.navigateToUser(
                      context,
                      widget.post.author,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing3),
                  Text(
                    widget.post.title,
                    style: colors.theme.textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  ContentPreview(post: widget.post, isCompact: false),
                  if (widget.post.selftext != null &&
                      widget.post.selftext!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    CommentContent(
                      content: widget.post.selftext!,
                      textStyle: colors.theme.textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing4),
                  ContentWidgets.engagementMetrics(
                    context: context,
                    score: widget.post.score,
                    commentCount: widget.post.numComments,
                    iconSize: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),

            if (tree.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing4,
                  AppTheme.spacing2,
                  AppTheme.spacing4,
                  AppTheme.spacing2,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Comments',
                        style: colors.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ContentWidgets.bullet(colors),
                      ),
                      TextSpan(
                        text: FormatUtils.formatNumber(
                          widget.post.numComments,
                        ),
                        style: colors.theme.textTheme.titleMedium?.copyWith(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading && tree.isEmpty)
              LoadingWidgets.loadingIndicatorPadded(context)
            else if (tree.isEmpty)
              LoadingWidgets.emptyState(context, 'No comments yet')
            else
              ...tree.map(
                (comment) => CommentTile(
                  key: ValueKey(comment.id),
                  comment: comment,
                  onAuthorTap: (username) =>
                      NavigationHelper.navigateToUser(context, username),
                  onLoadMore: _onMoreTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
