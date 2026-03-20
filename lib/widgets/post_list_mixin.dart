import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../constants/app_constants.dart';

/// Mixin for screens that display paginated lists of Reddit posts
mixin PostListMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  List<RedditPost> posts = [];
  bool isLoading = false;

  /// Override this to implement the actual post loading logic
  Future<List<RedditPost>> loadPostsImplementation({String? after});

  /// Override this to implement refresh logic if needed (optional)
  Future<void> onRefresh() async {
    await loadPosts();
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// Scroll handler - isLoading flag prevents duplicate calls
  void _onScroll() {
    if (isLoading) return;

    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent * AppConstants.scrollLoadThreshold) {
      loadMorePosts();
    }
  }

  /// Load initial posts
  Future<void> loadPosts() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final newPosts = await loadPostsImplementation();

      if (mounted) {
        setState(() {
          posts = newPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Failed to load posts. Please try again.');
      }
    }
  }

  /// Load more posts for pagination.
  /// Sets isLoading without setState to avoid rebuilding the list mid-scroll,
  /// which would change itemCount/maxScrollExtent and disrupt ballistic physics.
  Future<void> loadMorePosts() async {
    if (isLoading || posts.isEmpty) return;
    isLoading = true;

    try {
      final lastPost = posts.last;
      final newPosts = await loadPostsImplementation(after: 't3_${lastPost.id}');

      if (mounted) {
        final existingIds = posts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts.where((p) => !existingIds.contains(p.id)).toList();

        setState(() {
          posts.addAll(uniqueNewPosts);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load more posts.');
      }
    }

    isLoading = false;
  }

  /// Clear posts and reload (used when changing filters/sorts)
  void clearAndReload() {
    setState(() {
      posts = [];
    });
    loadPosts();
  }

  /// Show error feedback to user
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
