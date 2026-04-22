import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../constants/app_constants.dart';

mixin PostListMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  List<RedditPost> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  String? loadError;

  Future<List<RedditPost>> loadPostsImplementation({String? after});

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
      isLoading = posts.isEmpty;
      loadError = null;
      hasMore = true;
    });

    try {
      final newPosts = await loadPostsImplementation();
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
      if (mounted) setState(() => hasMore = false);
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
      posts = cached ?? [];
      hasMore = true;
      loadError = null;
    });
    loadPosts();
  }
}
