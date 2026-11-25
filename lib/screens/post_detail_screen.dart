import 'package:material_ui/material_ui.dart';
import '../models/comments_page.dart';
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
import '../utils/reddit_link.dart';
import '../utils/url_utils.dart';
import '../utils/navigation_helper.dart';
import '../constants/sort_constants.dart';

class PostDetailScreen extends StatefulWidget {
  /// The listing's post, shown until its page loads.
  final RedditPost? post;

  /// The thread to open when no listing post is at hand.
  final ThreadLink? link;

  const PostDetailScreen({super.key, required RedditPost this.post})
    : link = null;

  const PostDetailScreen.fromLink(ThreadLink this.link, {super.key})
    : post = null;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final RedditService _redditService = RedditService();
  final ScrollController _scrollController = ScrollController();

  /// The listing post at first, then the page's own version with selftext and gallery.
  late RedditPost? _post = widget.post;
  late String? _permalink = widget.post?.permalink ?? widget.link?.path;
  late String? _context = widget.link?.context;

  /// Set while one comment's thread is shown instead of the whole post.
  late String? _focusedCommentId = widget.link?.commentId;

  List<RedditComment> _tree = const [];
  bool _isLoading = false;
  bool _loadFailed = false;
  String _commentSort = SortConstants.confidence;
  int _loadToken = 0;

  String get _subreddit =>
      widget.post?.subreddit ?? widget.link?.subreddit ?? '';
  String get _postId => widget.post?.id ?? widget.link!.postId;

  @override
  void initState() {
    super.initState();
    final cached = _redditService.peekComments(
      _subreddit,
      _postId,
      sort: _commentSort,
      permalink: _permalink,
      context: _context,
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
    setState(() {
      _isLoading = _tree.isEmpty;
      _loadFailed = false;
    });
    try {
      final page = await _redditService.getComments(
        _subreddit,
        _postId,
        sort: _commentSort,
        permalink: _permalink,
        context: _context,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _post = page.post ?? widget.post;
        _tree = page.comments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _changeCommentSort(String sort) {
    setState(() {
      _commentSort = sort;
      _tree = const [];
    });
    _loadComments();
  }

  void _showAllComments() {
    setState(() {
      _permalink = _post?.permalink ?? '/comments/$_postId/';
      _context = null;
      _focusedCommentId = null;
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
    if (fetched == null || !mounted || token != _loadToken) return;
    final merged = _spliceMore(_tree, placeholder, fetched);
    setState(() => _tree = merged);
    _redditService.cacheExpandedComments(
      _subreddit,
      _postId,
      _commentSort,
      CommentsPage(post: _post, comments: merged),
      permalink: _permalink,
      context: _context,
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
          if (post != null && UrlUtils.canSummarize(post.url))
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
            if (post != null) ...[
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
                      onSubredditTap: () =>
                          NavigationHelper.navigateToSubreddit(
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
            ],

            if (_focusedCommentId != null && tree.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Single comment thread',
                        style: colors.theme.textTheme.labelMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _showAllComments,
                      child: const Text('View all comments'),
                    ),
                  ],
                ),
              ),

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
                      if (post != null) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: ContentWidgets.bullet(colors),
                        ),
                        TextSpan(
                          text: FormatUtils.formatNumber(post.numComments),
                          style: colors.theme.textTheme.titleMedium?.copyWith(
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (_isLoading && tree.isEmpty)
              LoadingWidgets.loadingIndicatorPadded(context)
            else if (_loadFailed && tree.isEmpty)
              LoadingWidgets.errorState(
                context,
                'Failed to load comments.',
                _loadComments,
              )
            else if (tree.isEmpty)
              LoadingWidgets.emptyState(context, 'No comments yet')
            else
              ...tree.map(
                (comment) => CommentTile(
                  key: ValueKey(comment.id),
                  comment: comment,
                  focusedId: _focusedCommentId,
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
