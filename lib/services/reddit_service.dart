import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import '../constants/sort_constants.dart';
import 'reddit_cache.dart';
import 'request_pipeline.dart';

/// A parsed post page: the post enriched with selftext/gallery (absent from
/// listings, since old.reddit lazy-loads them) plus its comment tree.
class CommentsPage {
  final RedditPost? post;
  final List<RedditComment> comments;
  const CommentsPage({this.post, this.comments = const []});
}

class RedditService {
  RedditService._internal();
  static final RedditService _instance = RedditService._internal();
  factory RedditService() => _instance;

  static const String _host = 'old.reddit.com';

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

  Future<CommentsPage> getComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
  }) => _withCache<CommentsPage>(
    bucket: CacheBucket.comments,
    uri: _commentsUri(subreddit, postId, sort: sort),
    parse: (doc) => _parseCommentsPage(doc, subreddit, postId),
  );

  /// Expand a "more replies" placeholder by re-fetching the parent thread's
  /// HTML (the JSON morechildren API is blocked). Returns the freshly parsed
  /// things at the placeholder's location — a single re-expanded parent
  /// comment, or the full top-level list when the placeholder was post-level.
  Future<List<RedditComment>> loadMoreComments({
    required String permalink,
    required String parentFullname,
    String sort = SortConstants.confidence,
  }) async {
    final base = Uri.parse(permalink);
    final uri = base.replace(
      queryParameters: {...base.queryParameters, 'sort': sort},
    );
    final body = await RequestPipeline.instance.getHtml(uri);
    if (body == null) return const [];
    try {
      final doc = html_parser.parse(body);
      final table = doc.querySelector('.commentarea .sitetable');
      if (table == null) return const [];
      return RedditComment.parseThings(table, 0, permalink, parentFullname);
    } catch (_) {
      return const [];
    }
  }

  Future<RedditUser> getUserInfo(String username) async {
    try {
      return await _withCache<RedditUser>(
        bucket: CacheBucket.userInfo,
        uri: _userInfoUri(username),
        parse: (doc) => RedditUser.fromUserPage(doc, username),
      );
    } on RedditServiceException {
      return RedditUser.empty(username);
    }
  }

  Future<List<Subreddit>> searchSubreddits(String query) {
    final uri = Uri.https(_host, '/subreddits/search', {'q': query});
    final queryLower = query.toLowerCase();
    return _withCache<List<Subreddit>>(
      bucket: CacheBucket.subredditSearch,
      uri: uri,
      parse: (doc) {
        final subs = doc
            .querySelectorAll('div.thing.subreddit')
            .map(Subreddit.fromThing)
            .where((s) => s.displayName.isNotEmpty)
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

  CommentsPage? peekComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
  }) => _peek<CommentsPage>(
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
      '$path/$sort/',
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
      '/user/$username/submitted/',
      params.isNotEmpty ? params : null,
    );
  }

  Uri _userInfoUri(String username) =>
      Uri.https(_host, '/user/$username/');

  Uri _commentsUri(String subreddit, String postId, {required String sort}) =>
      Uri.https(_host, '/r/$subreddit/comments/$postId/', {'sort': sort});

  Future<T> _withCache<T>({
    required CacheBucket bucket,
    required Uri uri,
    required T Function(Document doc) parse,
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

  Future<T?> _fetchAndParse<T>(Uri uri, T Function(Document doc) parse) async {
    final body = await RequestPipeline.instance.getHtml(uri);
    if (body == null) return null;
    try {
      return parse(html_parser.parse(body));
    } catch (_) {
      return null;
    }
  }

  /// Parse a listing page (`#siteTable`) into posts, skipping promoted ads and
  /// non-link things (subreddit announcement rows, etc.).
  List<RedditPost> _parsePosts(Document doc) {
    final table = doc.getElementById('siteTable');
    if (table == null) return const [];
    return table.children
        .where((e) => e.classes.contains('thing'))
        .where((e) => (e.attributes['data-fullname'] ?? '').startsWith('t3_'))
        .where((e) => e.attributes['data-promoted'] != 'true')
        .map(RedditPost.fromThing)
        .toList();
  }

  CommentsPage _parseCommentsPage(Document doc, String subreddit, String postId) {
    final postThing = doc.querySelector('#siteTable div.thing');
    final post = (postThing != null &&
            (postThing.attributes['data-fullname'] ?? '').startsWith('t3_'))
        ? RedditPost.fromThing(postThing)
        : null;

    final permalink = postThing?.attributes['data-permalink'] ??
        '/r/$subreddit/comments/$postId/';
    final table = doc.querySelector('.commentarea .sitetable');
    final comments = table == null
        ? const <RedditComment>[]
        : RedditComment.parseThings(table, 0, permalink, 't3_$postId');

    return CommentsPage(post: post, comments: comments);
  }

  void cacheExpandedComments(
    String subreddit,
    String postId,
    String sort,
    CommentsPage page,
  ) {
    RedditCache.instance.put(
      _commentsUri(subreddit, postId, sort: sort).toString(),
      page,
    );
  }
}

class RedditServiceException implements Exception {
  final String message;
  const RedditServiceException(this.message);
  @override
  String toString() => 'RedditServiceException: $message';
}
