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

  /// The post we render. Starts as the lean listing post, then upgrades to the
  /// post-page version (selftext + gallery) once comments load.
  late RedditPost _post = widget.post;
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
    if (cached != null) {
      _post = cached.post ?? widget.post;
      _tree = cached.comments;
    }
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
      final page = await _redditService.getComments(
        widget.post.subreddit,
        widget.post.id,
        sort: _commentSort,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _post = page.post ?? widget.post;
        _tree = page.comments;
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
    final permalink = placeholder.morePermalink;
    if (permalink == null) return;
    final token = _loadToken;
    final fetched = await _redditService.loadMoreComments(
      permalink: permalink,
      parentFullname: placeholder.parentId ?? '',
      sort: _commentSort,
    );
    if (!mounted || token != _loadToken) return;
    final merged = _spliceMore(_tree, placeholder, fetched);
    setState(() => _tree = merged);
    _redditService.cacheExpandedComments(
      widget.post.subreddit,
      widget.post.id,
      _commentSort,
      CommentsPage(post: _post, comments: merged),
    );
  }

  /// Replace a "more" placeholder with freshly fetched content. A comment-level
  /// placeholder swaps its parent comment for the re-expanded subtree; a
  /// post-level one replaces the whole top-level list.
  List<RedditComment> _spliceMore(
    List<RedditComment> tree,
    RedditComment placeholder,
    List<RedditComment> fetched,
  ) {
    final pid = placeholder.parentId ?? '';
    if (pid.startsWith('t1_')) {
      final targetId = pid.substring(3);
      RedditComment? fresh;
      for (final c in fetched) {
        if (c.id == targetId) {
          fresh = c;
          break;
        }
      }
      fresh ??= fetched.isNotEmpty ? fetched.first : null;
      if (fresh == null) return _removePlaceholder(tree, placeholder.id);
      return _replaceComment(tree, targetId, fresh);
    }
    if (fetched.isNotEmpty) {
      return [for (final c in fetched) _rebase(c, 0)];
    }
    return _removePlaceholder(tree, placeholder.id);
  }

  List<RedditComment> _replaceComment(
    List<RedditComment> list,
    String targetId,
    RedditComment replacement,
  ) {
    final out = <RedditComment>[];
    for (final c in list) {
      if (!c.isMorePlaceholder && c.id == targetId) {
        out.add(_rebase(replacement, c.depth));
      } else if (c.replies.isNotEmpty) {
        out.add(c.copyWith(
          replies: _replaceComment(c.replies, targetId, replacement),
        ));
      } else {
        out.add(c);
      }
    }
    return out;
  }

  List<RedditComment> _removePlaceholder(
    List<RedditComment> list,
    String placeholderId,
  ) {
    final out = <RedditComment>[];
    for (final c in list) {
      if (c.isMorePlaceholder && c.id == placeholderId) continue;
      if (c.replies.isNotEmpty) {
        out.add(c.copyWith(replies: _removePlaceholder(c.replies, placeholderId)));
      } else {
        out.add(c);
      }
    }
    return out;
  }

  /// Re-base a freshly fetched subtree (rendered at depth 0 on its own page) to
  /// the depth it occupies in our tree.
  RedditComment _rebase(RedditComment c, int depth) => c.copyWith(
        depth: depth,
        replies: [for (final r in c.replies) _rebase(r, depth + 1)],
      );

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final post = _post;
    final tree = _tree;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _scrollToTop,
          child: const Text('Post'),
        ),
        actions: [
          if (UrlUtils.canSummarize(post.url))
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => ArticleSummaryWidget.showSummary(
                context: context,
                url: post.url!,
                title: post.title,
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
                    subreddit: post.subreddit,
                    author: post.author,
                    timeAgo: FormatUtils.formatTime(post.created),
                    onSubredditTap: () => NavigationHelper.navigateToSubreddit(
                      context,
                      post.subreddit,
                    ),
                    onAuthorTap: () => NavigationHelper.navigateToUser(
                      context,
                      post.author,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing3),
                  Text(
                    post.title,
                    style: colors.theme.textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  ContentPreview(post: post, isCompact: false),
                  if (post.selftext != null && post.selftext!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    CommentContent(
                      content: post.selftext!,
                      textStyle: colors.theme.textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing4),
                  ContentWidgets.engagementMetrics(
                    context: context,
                    score: post.score,
                    commentCount: post.numComments,
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
                          post.numComments,
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
