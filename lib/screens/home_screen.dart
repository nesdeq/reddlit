import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../widgets/modal_widgets.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../widgets/post_list_view.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../constants/sort_constants.dart';
import 'subreddit_search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with PostListMixin {
  final RedditService _redditService = RedditService();

  String _currentSort = SortConstants.hot;
  String? _currentTopTime;
  String? _currentSubreddit;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await context.read<ThemeProvider>().ready;
    if (!mounted) return;
    _loadPostsFromDefault();
  }

  void _setSubreddit(String value) {
    _currentSubreddit = value == 'frontpage' ? null : value;
  }

  void _loadPostsFromDefault() {
    setState(
      () => _setSubreddit(context.read<ThemeProvider>().defaultSubreddit),
    );
    // Seed from cache synchronously — before loadPosts fires — so a warm
    // hit means no spinner on bootstrap.
    final cached = peekCachedPosts();
    if (cached != null && cached.isNotEmpty) {
      setState(() => posts = cached);
    }
    loadPosts();
  }

  @override
  Future<List<RedditPost>> loadPostsImplementation({
    String? after,
    void Function(List<RedditPost>)? onRefresh,
  }) async {
    if (_currentSubreddit == 'personal') {
      final favorites = context
          .read<ThemeProvider>()
          .favoriteSubreddits
          .toList();
      return _redditService.getPersonalPosts(
        favorites,
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
        onRefresh: onRefresh,
      );
    } else if (_currentSubreddit != null) {
      return _redditService.getSubredditPosts(
        _currentSubreddit!,
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
        onRefresh: onRefresh,
      );
    } else {
      return _redditService.getFrontpage(
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
        onRefresh: onRefresh,
      );
    }
  }

  @override
  List<RedditPost>? peekCachedPosts() {
    if (_currentSubreddit == 'personal') {
      final favorites = context
          .read<ThemeProvider>()
          .favoriteSubreddits
          .toList();
      return _redditService.peekPersonalPosts(
        favorites,
        sort: _currentSort,
        topTime: _currentTopTime,
      );
    }
    if (_currentSubreddit != null) {
      return _redditService.peekSubredditPosts(
        _currentSubreddit!,
        sort: _currentSort,
        topTime: _currentTopTime,
      );
    }
    return _redditService.peekFrontpage(
      sort: _currentSort,
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

  void _showSubredditSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubredditSearchScreen()),
    );
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      // Reload if default subreddit was changed
      _loadPostsFromDefault();
    });
  }

  void _showDefaultSubredditDialog() {
    ModalWidgets.showDefaultSubredditModal(
      context: context,
      currentDefault: context.read<ThemeProvider>().defaultSubreddit,
      onSelected: (value) async {
        await context.read<ThemeProvider>().setDefaultSubreddit(value);
        if (!mounted) return;
        setState(() => _setSubreddit(value));
        clearAndReload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: scrollToTop,
          child: const Text('Reddlit'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: _showDefaultSubredditDialog,
            tooltip: 'Default subreddit',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: _showSubredditSearch,
            tooltip: 'Search subreddits',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => SortDialogs.showPostSortModal(
              context: context,
              currentSort: _currentSort,
              currentTopTime: _currentTopTime,
              onSortChanged: _changeSort,
            ),
            tooltip: 'Sort posts',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _showSettings,
            tooltip: 'Settings',
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
