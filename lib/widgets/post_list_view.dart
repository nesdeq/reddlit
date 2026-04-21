import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../theme/app_theme.dart';
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

  const PostListView({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    if (isLoading && posts.isEmpty) {
      return LoadingWidgets.loadingIndicator(context);
    }

    if (errorMessage != null && posts.isEmpty) {
      return _ErrorState(message: errorMessage!, onRetry: onRetry);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.accentColor,
      child: ListView.builder(
        controller: scrollController,
        cacheExtent: MediaQuery.of(context).size.height * 0.5,
        itemCount: posts.length + ((isLoading || !hasMore) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            if (isLoading) return LoadingWidgets.loadingIndicatorPadded(context);
            return LoadingWidgets.emptyState(context, 'No more posts');
          }
          final post = posts[index];
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: colors.textTertiary,
              size: 48,
            ),
            const SizedBox(height: AppTheme.spacing3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: colors.theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: colors.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
