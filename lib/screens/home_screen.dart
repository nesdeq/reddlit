import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../widgets/post_card.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/modal_widgets.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../constants/sort_constants.dart';
import '../utils/navigation_helper.dart';
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
  bool _hasLoadedFromDefault = false;

  @override
  void initState() {
    super.initState();
    // Add listener to load default when prefs are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = context.read<ThemeProvider>();
      if (themeProvider.isPrefsLoaded) {
        // Prefs already loaded, load immediately
        _loadPostsFromDefault();
      } else {
        // Prefs not loaded yet, add listener
        themeProvider.addListener(_onPrefsLoaded);
      }
    });
  }

  void _onPrefsLoaded() {
    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.isPrefsLoaded && !_hasLoadedFromDefault) {
      _hasLoadedFromDefault = true;
      themeProvider.removeListener(_onPrefsLoaded);
      _loadPostsFromDefault();
    }
  }

  void _setSubreddit(String value) {
    _currentSubreddit = value == 'frontpage' ? null : value;
  }

  void _loadPostsFromDefault() {
    setState(() => _setSubreddit(context.read<ThemeProvider>().defaultSubreddit));
    loadPosts();
  }

  @override
  Future<List<RedditPost>> loadPostsImplementation({String? after}) async {
    if (_currentSubreddit == 'personal') {
      // Personal Selection: fetch from all favorited subreddits
      final favorites = context.read<ThemeProvider>().favoriteSubreddits.toList();
      return await _redditService.getPersonalPosts(
        favorites,
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
      );
    } else if (_currentSubreddit != null) {
      return await _redditService.getSubredditPosts(
        _currentSubreddit!,
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
      );
    } else {
      return await _redditService.getFrontpage(
        sort: _currentSort,
        after: after,
        topTime: _currentTopTime,
      );
    }
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
      onSelected: _changeDefaultSubreddit,
    );
  }

  Future<void> _changeDefaultSubreddit(String value) async {
    await context.read<ThemeProvider>().setDefaultSubreddit(value);
    if (mounted) {
      Navigator.pop(context);
      setState(() => _setSubreddit(value));
      clearAndReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Reddlit'),
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
