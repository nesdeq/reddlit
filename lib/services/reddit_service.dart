import 'dart:async';

import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import '../constants/sort_constants.dart';
import 'reddit_cache.dart';
import 'request_pipeline.dart';

/// Thin wrapper around reddit.com's public JSON endpoints.
///
/// All reads go through [RequestPipeline] (throttled, deduped, retrying) and
/// [RedditCache] (stale-while-revalidate). Every read method accepts an
/// optional `onRefresh` callback that fires when a stale response has been
/// quietly replaced by a fresh one in the background — this is how screens
/// update without ever showing a spinner on repeat visits.
///
/// Terminal failures return empty values; callers render an empty/error state
/// of their choosing.
class RedditService {
  RedditService._internal();
  static final RedditService _instance = RedditService._internal();
  factory RedditService() => _instance;

  Future<List<RedditPost>> getFrontpage({
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
    void Function(List<RedditPost>)? onRefresh,
  }) => _fetchPosts(
    path: '',
    sort: sort,
    after: after,
    topTime: topTime,
    onRefresh: onRefresh,
  );

  Future<List<RedditPost>> getSubredditPosts(
    String subreddit, {
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
    void Function(List<RedditPost>)? onRefresh,
  }) => _fetchPosts(
    path: '/r/$subreddit',
    sort: sort,
    after: after,
    topTime: topTime,
    onRefresh: onRefresh,
  );

  /// Fetch posts from multiple subreddits via Reddit's `r/a+b+c` syntax.
  Future<List<RedditPost>> getPersonalPosts(
    List<String> subreddits, {
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
    void Function(List<RedditPost>)? onRefresh,
  }) {
    if (subreddits.isEmpty) return Future.value(const []);
    return _fetchPosts(
      path: '/r/${subreddits.join('+')}',
      sort: sort,
      after: after,
      topTime: topTime,
      onRefresh: onRefresh,
    );
  }

  Future<List<RedditPost>> getUserPosts(
    String username, {
    String? after,
    void Function(List<RedditPost>)? onRefresh,
  }) => _withCache<List<RedditPost>>(
    bucket: CacheBucket.postList,
    uri: _userPostsUri(username, after: after),
    parse: _parsePosts,
    onRefresh: onRefresh,
  );

  Future<List<RedditPost>> _fetchPosts({
    required String path,
    required String sort,
    String? after,
    String? topTime,
    void Function(List<RedditPost>)? onRefresh,
  }) => _withCache<List<RedditPost>>(
    bucket: CacheBucket.postList,
    uri: _postsUri(path, sort: sort, after: after, topTime: topTime),
    parse: _parsePosts,
    onRefresh: onRefresh,
  );

  Future<List<RedditComment>> getComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
    void Function(List<RedditComment>)? onRefresh,
  }) => _withCache<List<RedditComment>>(
    bucket: CacheBucket.comments,
    uri: _commentsUri(subreddit, postId, sort: sort),
    parse: _parseCommentListing,
    onRefresh: onRefresh,
  );

  /// Expand one `more` placeholder. Not cached — each placeholder is fetched
  /// at most once per app session via pipeline dedup on the URL.
  Future<List<RedditComment>> loadMoreComments({
    required String linkId,
    required List<String> childIds,
    String sort = SortConstants.confidence,
  }) async {
    if (childIds.isEmpty) return const [];
    final uri = Uri.https(_host, '/api/morechildren.json', {
      'api_type': 'json',
      'link_id': linkId,
      'children': childIds.join(','),
      'sort': sort,
    });
    final body = await RequestPipeline.instance.getJson(uri);
    if (body is! Map) return const [];
    final things = body['json']?['data']?['things'];
    if (things is! List) return const [];
    return things
        .where((c) => c['kind'] == 't1' || c['kind'] == 'more')
        .map((c) => RedditComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<RedditUser> getUserInfo(
    String username, {
    void Function(RedditUser)? onRefresh,
  }) async {
    try {
      return await _withCache<RedditUser>(
        bucket: CacheBucket.userInfo,
        uri: _userInfoUri(username),
        parse: (body) => RedditUser.fromJson(body as Map<String, dynamic>),
        onRefresh: onRefresh,
      );
    } on RedditServiceException {
      // User info is non-critical header metadata — fall back to an empty
      // shell so the posts list below still renders.
      return RedditUser.empty(username);
    }
  }

  /// Search for subreddits whose NAME contains [query], sorted by subscribers.
  Future<List<Subreddit>> searchSubreddits(String query) {
    final uri = Uri.https(_host, '/subreddits/search.json', {
      'q': query,
      'limit': '100',
      'include_over_18': 'on',
    });
    final queryLower = query.toLowerCase();
    return _withCache<List<Subreddit>>(
      bucket: CacheBucket.subredditSearch,
      uri: uri,
      parse: (body) {
        final map = body as Map<String, dynamic>;
        final children = map['data']['children'] as List;
        final subs = children
            .where((c) => c['kind'] == 't5')
            .map((c) => Subreddit.fromJson(c as Map<String, dynamic>))
            .where((s) => s.displayName.toLowerCase().contains(queryLower))
            .toList();
        subs.sort((a, b) => b.subscribers.compareTo(a.subscribers));
        return subs;
      },
      onRefresh: null,
    );
  }

  // ------------- Synchronous cache peeks -------------
  // Used by screens to seed state from cache before the first frame, so
  // repeat visits never show a spinner.

  List<RedditPost>? peekFrontpage({
    String sort = SortConstants.hot,
    String? topTime,
  }) => _peekPosts(path: '', sort: sort, topTime: topTime);

  List<RedditPost>? peekSubredditPosts(
    String subreddit, {
    String sort = SortConstants.hot,
    String? topTime,
  }) => _peekPosts(path: '/r/$subreddit', sort: sort, topTime: topTime);

  List<RedditPost>? peekPersonalPosts(
    List<String> subreddits, {
    String sort = SortConstants.hot,
    String? topTime,
  }) {
    if (subreddits.isEmpty) return null;
    return _peekPosts(
      path: '/r/${subreddits.join('+')}',
      sort: sort,
      topTime: topTime,
    );
  }

  List<RedditPost>? peekUserPosts(String username) => _peek<List<RedditPost>>(
    CacheBucket.postList,
    _userPostsUri(username),
  );

  RedditUser? peekUserInfo(String username) =>
      _peek<RedditUser>(CacheBucket.userInfo, _userInfoUri(username));

  List<RedditComment>? peekComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
  }) => _peek<List<RedditComment>>(
    CacheBucket.comments,
    _commentsUri(subreddit, postId, sort: sort),
  );

  List<RedditPost>? _peekPosts({
    required String path,
    required String sort,
    String? topTime,
  }) => _peek<List<RedditPost>>(
    CacheBucket.postList,
    _postsUri(path, sort: sort, topTime: topTime),
  );

  T? _peek<T>(CacheBucket bucket, Uri uri) =>
      RedditCache.instance.lookup<T>(bucket, uri.toString())?.value;

  // ------------- Prefetch hooks (fire-and-forget) -------------
  // All prefetches swallow failures — a warm-cache optimization has no
  // business bubbling errors up as unhandled async exceptions.

  void prefetchComments(String subreddit, String postId) {
    _fireAndForget(getComments(subreddit, postId));
  }

  void prefetchSubredditPosts(String subreddit) {
    _fireAndForget(getSubredditPosts(subreddit));
  }

  void prefetchUserInfo(String username) {
    _fireAndForget(getUserInfo(username));
  }

  void prefetchUserPosts(String username) {
    _fireAndForget(getUserPosts(username));
  }

  void _fireAndForget(Future<Object?> future) {
    // `then<void>(...)` gives us a Future<void> whose onError returns void —
    // unlike catchError, which requires returning the ORIGINAL future's type
    // and would throw TypeError when returning null for a Future<List<X>>.
    unawaited(future.then<void>((_) {}, onError: (_) {}));
  }

  // ------------- URI builders -------------
  // Every endpoint has exactly one URL shape shared between its fetch and
  // peek paths, so the cache key generated by `_withCache` and the key
  // checked by `peek*` can never drift.

  static const String _host = 'www.reddit.com';

  Uri _postsUri(
    String path, {
    required String sort,
    String? after,
    String? topTime,
  }) {
    final params = <String, String>{};
    if (after != null) params['after'] = after;
    if (sort == SortConstants.top && topTime != null) params['t'] = topTime;
    return Uri.https(
      _host,
      '$path/$sort.json',
      params.isNotEmpty ? params : null,
    );
  }

  Uri _userPostsUri(String username, {String? after}) => Uri.https(
    _host,
    '/user/$username/submitted.json',
    after != null ? {'after': after} : null,
  );

  Uri _userInfoUri(String username) =>
      Uri.https(_host, '/user/$username/about.json');

  Uri _commentsUri(String subreddit, String postId, {required String sort}) =>
      Uri.https(_host, '/r/$subreddit/comments/$postId.json', {'sort': sort});

  // ------------- Internals -------------

  Future<T> _withCache<T>({
    required CacheBucket bucket,
    required Uri uri,
    required T Function(dynamic body) parse,
    required void Function(T)? onRefresh,
  }) async {
    final key = uri.toString();
    final hit = RedditCache.instance.lookup<T>(bucket, key);

    if (hit != null) {
      if (hit.isStale) {
        // Background refresh failures are silent — cached value stays visible.
        RedditCache.instance.backgroundRefresh<T>(
          key,
          () => _fetchAndParse<T>(uri, parse),
          onRefresh,
        );
      }
      return hit.value;
    }

    final fresh = await _fetchAndParse<T>(uri, parse);
    if (fresh == null) {
      // Hard failure on a cold read — throw so the UI can show a real error
      // state with a retry affordance, rather than rendering an empty list
      // indistinguishable from "nothing to see here."
      throw const RedditServiceException('Network request failed.');
    }
    RedditCache.instance.put(key, fresh as Object);
    return fresh;
  }

  Future<T?> _fetchAndParse<T>(Uri uri, T Function(dynamic body) parse) async {
    final body = await RequestPipeline.instance.getJson(uri);
    if (body == null) return null;
    try {
      return parse(body);
    } catch (_) {
      return null;
    }
  }

  List<RedditPost> _parsePosts(dynamic body) {
    final map = body as Map<String, dynamic>;
    final children = map['data']['children'] as List;
    return children
        .where((c) => c['kind'] == 't3')
        .map((c) => RedditPost.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  List<RedditComment> _parseCommentListing(dynamic body) {
    if (body is! List || body.length < 2) return const [];
    final children = body[1]['data']['children'] as List;
    return children
        .where((c) => c['kind'] == 't1' || c['kind'] == 'more')
        .map((c) => RedditComment.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}

/// Thrown by [RedditService] when a cold read ultimately fails — all pipeline
/// retries exhausted, no cache to fall back on. Callers catch this to show
/// an error state instead of rendering empty content as if it were success.
class RedditServiceException implements Exception {
  final String message;
  const RedditServiceException(this.message);
  @override
  String toString() => 'RedditServiceException: $message';
}
