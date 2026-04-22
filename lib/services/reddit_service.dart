import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import '../constants/sort_constants.dart';
import 'reddit_cache.dart';
import 'request_pipeline.dart';

class RedditService {
  RedditService._internal();
  static final RedditService _instance = RedditService._internal();
  factory RedditService() => _instance;

  static const String _host = 'www.reddit.com';

  Future<List<RedditPost>> getFrontpage({
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
  }) => _fetchPosts(path: '', sort: sort, after: after, topTime: topTime);

  Future<List<RedditPost>> getSubredditPosts(
    String subreddit, {
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
  }) => _fetchPosts(
    path: '/r/$subreddit',
    sort: sort,
    after: after,
    topTime: topTime,
  );

  Future<List<RedditPost>> getPersonalPosts(
    List<String> subreddits, {
    String sort = SortConstants.hot,
    String? after,
    String? topTime,
  }) {
    if (subreddits.isEmpty) return Future.value(const []);
    return _fetchPosts(
      path: '/r/${subreddits.join('+')}',
      sort: sort,
      after: after,
      topTime: topTime,
    );
  }

  Future<List<RedditPost>> getUserPosts(
    String username, {
    String? after,
    String? sort,
    String? topTime,
  }) => _withCache<List<RedditPost>>(
    bucket: CacheBucket.postList,
    uri: _userPostsUri(
      username,
      after: after,
      sort: sort,
      topTime: topTime,
    ),
    parse: _parsePosts,
  );

  Future<List<RedditPost>> getFollowingPosts(
    List<String> usernames, {
    String sort = SortConstants.newSort,
    String? topTime,
  }) async {
    if (usernames.isEmpty) return const [];
    final results = await Future.wait(
      usernames.map(
        (u) => getUserPosts(u, sort: sort, topTime: topTime)
            .catchError((_) => const <RedditPost>[]),
      ),
    );
    return _mergePosts(results, sort);
  }

  List<RedditPost> _mergePosts(List<List<RedditPost>> streams, String sort) {
    final seen = <String>{};
    final merged = <RedditPost>[];
    for (final s in streams) {
      for (final p in s) {
        if (seen.add(p.id)) merged.add(p);
      }
    }
    if (sort == SortConstants.newSort) {
      merged.sort((a, b) => b.created.compareTo(a.created));
    } else {
      merged.sort((a, b) => b.score.compareTo(a.score));
    }
    return merged;
  }

  Future<List<RedditPost>> _fetchPosts({
    required String path,
    required String sort,
    String? after,
    String? topTime,
  }) => _withCache<List<RedditPost>>(
    bucket: CacheBucket.postList,
    uri: _postsUri(path, sort: sort, after: after, topTime: topTime),
    parse: _parsePosts,
  );

  Future<List<RedditComment>> getComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
  }) => _withCache<List<RedditComment>>(
    bucket: CacheBucket.comments,
    uri: _commentsUri(subreddit, postId, sort: sort),
    parse: _parseCommentListing,
  );

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

  Future<RedditUser> getUserInfo(String username) async {
    try {
      return await _withCache<RedditUser>(
        bucket: CacheBucket.userInfo,
        uri: _userInfoUri(username),
        parse: (body) => RedditUser.fromJson(body as Map<String, dynamic>),
      );
    } on RedditServiceException {
      return RedditUser.empty(username);
    }
  }

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
    );
  }

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

  List<RedditPost>? peekUserPosts(String username) =>
      _peek<List<RedditPost>>(CacheBucket.postList, _userPostsUri(username));

  List<RedditPost>? peekFollowingPosts(
    List<String> usernames, {
    String sort = SortConstants.newSort,
    String? topTime,
  }) {
    if (usernames.isEmpty) return null;
    final streams = <List<RedditPost>>[];
    for (final u in usernames) {
      final uri = _userPostsUri(u, sort: sort, topTime: topTime);
      final cached = _peek<List<RedditPost>>(CacheBucket.postList, uri);
      if (cached != null) streams.add(cached);
    }
    if (streams.isEmpty) return null;
    return _mergePosts(streams, sort);
  }

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
      RedditCache.instance.lookup<T>(bucket, uri.toString());

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

  Uri _userPostsUri(
    String username, {
    String? after,
    String? sort,
    String? topTime,
  }) {
    final params = <String, String>{};
    if (after != null) params['after'] = after;
    if (sort != null) params['sort'] = sort;
    if (sort == SortConstants.top && topTime != null) params['t'] = topTime;
    return Uri.https(
      _host,
      '/user/$username/submitted.json',
      params.isNotEmpty ? params : null,
    );
  }

  Uri _userInfoUri(String username) =>
      Uri.https(_host, '/user/$username/about.json');

  Uri _commentsUri(String subreddit, String postId, {required String sort}) =>
      Uri.https(_host, '/r/$subreddit/comments/$postId.json', {'sort': sort});

  Future<T> _withCache<T>({
    required CacheBucket bucket,
    required Uri uri,
    required T Function(dynamic body) parse,
  }) async {
    final key = uri.toString();
    final cached = RedditCache.instance.lookup<T>(bucket, key);
    if (cached != null) return cached;

    final fresh = await _fetchAndParse<T>(uri, parse);
    if (fresh == null) {
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

  void cacheExpandedComments(
    String subreddit,
    String postId,
    String sort,
    List<RedditComment> tree,
  ) {
    RedditCache.instance.put(
      _commentsUri(subreddit, postId, sort: sort).toString(),
      tree,
    );
  }
}

class RedditServiceException implements Exception {
  final String message;
  const RedditServiceException(this.message);
  @override
  String toString() => 'RedditServiceException: $message';
}
