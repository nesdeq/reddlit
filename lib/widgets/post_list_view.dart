import 'package:material_ui/material_ui.dart';
import '../models/reddit_post.dart';
import '../theme/theme_helper.dart';
import '../utils/navigation_helper.dart';
import 'loading_widgets.dart';
import 'post_card.dart';

/// Shared list view for paginated Reddit post feeds.
class PostListView extends StatelessWidget {
  final List<RedditPost> posts;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;

  /// Scrolls above the posts; with a header, first-page states render below it.
  final Widget? header;

  const PostListView({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final header = this.header;
    final failed = errorMessage != null && posts.isEmpty;

    if (header == null) {
      if (isLoading && posts.isEmpty) {
        return LoadingWidgets.loadingIndicator(context);
      }
      if (failed) {
        return LoadingWidgets.errorState(context, errorMessage!, onRetry);
      }
    }

    final lead = header == null ? 0 : 1;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.accentColor,
      child: ListView.builder(
        controller: scrollController,
        scrollCacheExtent: ScrollCacheExtent.pixels(
          MediaQuery.of(context).size.height * 0.5,
        ),
        itemCount:
            lead + posts.length + ((isLoading || !hasMore || failed) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < lead) return header!;
          final i = index - lead;
          if (i == posts.length) {
            if (isLoading) return LoadingWidgets.loadingIndicatorPadded(context);
            if (failed) {
              return LoadingWidgets.errorState(context, errorMessage!, onRetry);
            }
            return LoadingWidgets.emptyState(
              context,
              posts.isEmpty ? 'No posts yet' : 'No more posts',
            );
          }
          final post = posts[i];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onTap: () => NavigationHelper.navigateToPost(context, post),
          );
        },
      ),
    );
  }
}
