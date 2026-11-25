import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/post_feed.dart';
import '../services/settings_provider.dart';
import '../widgets/sort_dialogs.dart';
import '../widgets/post_list_mixin.dart';
import '../widgets/post_list_view.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

class SubredditScreen extends StatefulWidget {
  final String subreddit;

  const SubredditScreen({super.key, required this.subreddit});

  @override
  State<SubredditScreen> createState() => _SubredditScreenState();
}

class _SubredditScreenState extends State<SubredditScreen> with PostListMixin {
  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  @override
  PostFeed get feed => SubredditsFeed([widget.subreddit]);

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
              context.watch<SettingsProvider>().isFavorite(widget.subreddit)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () {
              Haptics.lightImpact();
              context.read<SettingsProvider>().toggleFavorite(widget.subreddit);
            },
            tooltip: 'Favorite',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => SortDialogs.showPostSortModal(
              context: context,
              currentSort: sort,
              currentTopTime: topTime,
              onSortChanged: changeSort,
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
        onRefresh: loadPosts,
        onRetry: loadPosts,
      ),
    );
  }
}
