import 'package:material_ui/material_ui.dart';
import '../models/post_feed.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../constants/app_constants.dart';
import '../constants/sort_constants.dart';

mixin PostListMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  List<RedditPost> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  String? loadError;
  String sort = SortConstants.hot;
  String? topTime;
  int _loadGeneration = 0;

  /// Continues the page [posts] ends with; null until a fresh first page has loaded.
  FeedCursor? _next;

  PostFeed get feed;

  Future<PostPage> loadPostsImplementation({FeedCursor? after}) =>
      RedditService().getPosts(feed, sort: sort, topTime: topTime, after: after);

  List<RedditPost>? peekCachedPosts() =>
      RedditService().peekPosts(feed, sort: sort, topTime: topTime);

  void changeSort(String sort, {String? topTime}) {
    setState(() {
      this.sort = sort;
      this.topTime = topTime;
    });
    clearAndReload();
  }

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
    final generation = ++_loadGeneration;
    setState(() {
      isLoading = posts.isEmpty;
      loadError = null;
      hasMore = true;
      _next = null;
    });

    try {
      final page = await loadPostsImplementation();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        posts = page.posts;
        _next = page.next;
        isLoading = false;
        hasMore = page.next != null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        isLoading = false;
        if (posts.isEmpty) loadError = 'Failed to load posts.';
      });
    }
  }

  Future<void> loadMorePosts() async {
    final after = _next;
    if (isLoading || !hasMore || after == null) return;
    final source = posts;
    isLoading = true;

    try {
      final page = await loadPostsImplementation(after: after);
      // A reload replaced the list this page continues: drop the page.
      if (!mounted || !identical(posts, source)) return;

      final existingIds = source.map((p) => p.id).toSet();
      final uniqueNewPosts = page.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();

      setState(() {
        posts = [...source, ...uniqueNewPosts];
        _next = page.next;
        hasMore = uniqueNewPosts.isNotEmpty && page.next != null;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted || !identical(posts, source)) return;
      setState(() {
        hasMore = false;
        isLoading = false;
      });
    }
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
