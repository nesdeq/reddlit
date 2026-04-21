import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../constants/app_constants.dart';

/// Mixin for screens that display paginated lists of Reddit posts.
///
/// Cooperates with [RedditService]'s stale-while-revalidate cache: screens
/// override [peekCachedPosts] to synchronously seed the list from cache on
/// first build, and forward [onRefresh] into service calls so background
/// refreshes update the UI without ever showing a spinner.
mixin PostListMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  List<RedditPost> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  String? loadError;

  /// Override to fetch posts from the network.
  /// [onRefresh] fires when the service has a fresher value than what was
  /// returned (stale-hit path) — screens forward it to the service.
  Future<List<RedditPost>> loadPostsImplementation({
    String? after,
    void Function(List<RedditPost>)? onRefresh,
  });

  /// Override to seed [posts] synchronously from cache before the first fetch.
  /// Returning non-null suppresses the initial spinner.
  List<RedditPost>? peekCachedPosts() => null;

  Future<void> onRefresh() => loadPosts();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    final cached = peekCachedPosts();
    if (cached != null && cached.isNotEmpty) {
      posts = cached;
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (isLoading || !hasMore || loadError != null) return;
    final position = scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent * AppConstants.scrollLoadThreshold) {
      loadMorePosts();
    }
  }

  Future<void> loadPosts() async {
    if (isLoading) return;

    setState(() {
      // Only show the full-screen spinner when we have nothing to render —
      // a warm cache means the list is already visible and the refresh is
      // silent.
      isLoading = posts.isEmpty;
      loadError = null;
      hasMore = true;
    });

    try {
      final newPosts = await loadPostsImplementation(
        onRefresh: (fresh) {
          if (!mounted) return;
          setState(() => posts = fresh);
        },
      );

      if (!mounted) return;
      setState(() {
        posts = newPosts;
        isLoading = false;
        hasMore = newPosts.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        if (posts.isEmpty) loadError = 'Failed to load posts.';
      });
    }
  }

  Future<void> retry() => loadPosts();

  /// Paginate. Uses a non-setState flag so the list physics stay smooth —
  /// toggling setState mid-scroll would change maxScrollExtent and disrupt
  /// ballistic scroll.
  Future<void> loadMorePosts() async {
    if (isLoading || !hasMore || posts.isEmpty) return;
    isLoading = true;

    try {
      final lastPost = posts.last;
      final newPosts = await loadPostsImplementation(
        after: 't3_${lastPost.id}',
      );

      if (!mounted) {
        isLoading = false;
        return;
      }

      final existingIds = posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      setState(() {
        posts.addAll(uniqueNewPosts);
        hasMore = uniqueNewPosts.isNotEmpty;
      });
    } catch (_) {
      if (mounted) _showErrorSnackBar('Failed to load more posts.');
    }

    isLoading = false;
  }

  void scrollToTop() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void clearAndReload() {
    final cached = peekCachedPosts();
    setState(() {
      // Seed from cache if available — on a sort/subreddit change, a warm
      // hit means the new list shows instantly and the refresh is silent.
      posts = cached ?? [];
      hasMore = true;
      loadError = null;
    });
    loadPosts();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
