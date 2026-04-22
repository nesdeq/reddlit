import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../widgets/post_list_view.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/haptics.dart';
import '../constants/sort_constants.dart';

class SubredditScreen extends StatefulWidget {
  final String subreddit;

  const SubredditScreen({super.key, required this.subreddit});

  @override
  State<SubredditScreen> createState() => _SubredditScreenState();
}

class _SubredditScreenState extends State<SubredditScreen> with PostListMixin {
  final RedditService _redditService = RedditService();

  String _currentSort = SortConstants.hot;
  String? _currentTopTime;

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  @override
  Future<List<RedditPost>> loadPostsImplementation({String? after}) {
    return _redditService.getSubredditPosts(
      widget.subreddit,
      sort: _currentSort,
      after: after,
      topTime: _currentTopTime,
    );
  }

  @override
  List<RedditPost>? peekCachedPosts() => _redditService.peekSubredditPosts(
    widget.subreddit,
    sort: _currentSort,
    topTime: _currentTopTime,
  );

  void _changeSort(String sort, {String? topTime}) {
    setState(() {
      _currentSort = sort;
      _currentTopTime = topTime;
    });
    clearAndReload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: scrollToTop,
          child: Text('r/${widget.subreddit}'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isFavorite(widget.subreddit)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () {
              Haptics.lightImpact();
              context.read<ThemeProvider>().toggleFavorite(widget.subreddit);
            },
            tooltip: 'Favorite',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => SortDialogs.showPostSortModal(
              context: context,
              currentSort: _currentSort,
              currentTopTime: _currentTopTime,
              onSortChanged: _changeSort,
            ),
          ),
          const SizedBox(width: AppTheme.spacing1),
        ],
      ),
      body: PostListView(
        posts: posts,
        isLoading: isLoading,
        hasMore: hasMore,
        errorMessage: loadError,
        scrollController: scrollController,
        onRefresh: onRefresh,
        onRetry: retry,
      ),
    );
  }
}
