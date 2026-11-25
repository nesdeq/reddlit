import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/post_feed.dart';
import '../services/auth_service.dart';
import '../services/settings_provider.dart';
import '../widgets/modal_widgets.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../widgets/post_list_view.dart';
import '../theme/app_theme.dart';
import 'subreddit_search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with PostListMixin {
  String? _currentSubreddit;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (AuthService.instance.isAuthenticated && posts.isEmpty) {
      _loadPostsFromDefault();
    }
  }

  Future<void> _bootstrap() async {
    await context.read<SettingsProvider>().ready;
    if (!mounted) return;
    _loadPostsFromDefault();
  }

  void _setSubreddit(String value) {
    _currentSubreddit = value == 'frontpage' ? null : value;
  }

  void _loadPostsFromDefault() {
    setState(
      () => _setSubreddit(context.read<SettingsProvider>().defaultSubreddit),
    );
    // Seed from cache before loading so a warm start shows no spinner.
    final cached = peekCachedPosts();
    if (cached != null && cached.isNotEmpty) {
      setState(() => posts = cached);
    }
    loadPosts();
  }

  @override
  PostFeed get feed {
    final settings = context.read<SettingsProvider>();
    return switch (_currentSubreddit) {
      null => const FrontpageFeed(),
      'personal' => SubredditsFeed(settings.favoriteSubreddits.toList()),
      'following' => FollowingFeed(settings.favoriteUsers.toList()),
      final name => SubredditsFeed([name]),
    };
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
      // Settings may have changed the default feed.
      _loadPostsFromDefault();
    });
  }

  void _showDefaultSubredditDialog() {
    ModalWidgets.showDefaultSubredditModal(
      context: context,
      currentDefault: context.read<SettingsProvider>().defaultSubreddit,
      onSelected: (value) async {
        await context.read<SettingsProvider>().setDefaultSubreddit(value);
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
              currentSort: sort,
              currentTopTime: topTime,
              onSortChanged: changeSort,
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
        onRefresh: loadPosts,
        onRetry: loadPosts,
      ),
    );
  }
}
