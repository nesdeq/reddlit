import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../widgets/post_card.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../constants/sort_constants.dart';
import '../utils/navigation_helper.dart';

class SubredditScreen extends StatefulWidget {
  final String subreddit;

  const SubredditScreen({
    super.key,
    required this.subreddit,
  });

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
  Future<List<RedditPost>> loadPostsImplementation({String? after}) async {
    return await _redditService.getSubredditPosts(
      widget.subreddit,
      sort: _currentSort,
      after: after,
      topTime: _currentTopTime,
    );
  }

  void _changeSort(String sort, {String? topTime}) {
    setState(() {
      _currentSort = sort;
      _currentTopTime = topTime;
    });
    clearAndReload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: Text('r/${widget.subreddit}'),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isFavorite(widget.subreddit)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () {
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
      body: isLoading && posts.isEmpty
          ? LoadingWidgets.loadingIndicator(context)
          : RefreshIndicator(
              onRefresh: onRefresh,
              color: colors.accentColor,
              child: ListView.builder(
                controller: scrollController,
                cacheExtent: MediaQuery.of(context).size.height * 0.5,
                itemCount: posts.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == posts.length) {
                    return LoadingWidgets.loadingIndicatorPadded(context);
                  }

                  final post = posts[index];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => NavigationHelper.navigateToPost(context, post),
                  );
                },
              ),
            ),
    );
  }
}
