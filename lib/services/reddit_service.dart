import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/comments_page.dart';
import '../models/post_feed.dart';
import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import '../constants/sort_constants.dart';
import '../utils/reddit_link.dart';
import 'reddit_cache.dart';
import 'request_pipeline.dart';

class RedditService {
  RedditService._internal();
  static final RedditService _instance = RedditService._internal();
  factory RedditService() => _instance;

  static const String _host = 'old.reddit.com';

  Future<List<RedditPost>> getPosts(
    PostFeed feed, {
    String sort = SortConstants.hot,
    String? topTime,
    String? after,
  }) async {
    final uris = _feedUris(feed, sort: sort, topTime: topTime, after: after);
    if (feed is! FollowingFeed) {
      return uris.isEmpty ? const [] : _getListing(uris.single);
    }
    final streams = await Future.wait(uris.map(
      (uri) => _getListing(uri).catchError((_) => const <RedditPost>[]),
    ));
    return _mergePosts(streams, sort);
  }

  List<RedditPost>? peekPosts(
    PostFeed feed, {
    String sort = SortConstants.hot,
    String? topTime,
  }) {
    final streams = _feedUris(feed, sort: sort, topTime: topTime)
        .map((uri) => _peek<List<RedditPost>>(CacheBucket.postList, uri))
        .nonNulls
        .toList();
    if (streams.isEmpty) return null;
    return feed is FollowingFeed ? _mergePosts(streams, sort) : streams.single;
  }

  /// The listing URIs [feed] requests: one per listing, one per followed user.
  List<Uri> _feedUris(
    PostFeed feed, {
    required String sort,
    String? topTime,
    String? after,
  }) => switch (feed) {
    FrontpageFeed() => [
      _postsUri('', sort: sort, after: after, topTime: topTime),
    ],
    SubredditsFeed(:final names) => [
      if (names.isNotEmpty)
        _postsUri(
          '/r/${names.join('+')}',
          sort: sort,
          after: after,
          topTime: topTime,
        ),
    ],
    UserFeed(:final username) => [_userPostsUri(username, after: after)],
    FollowingFeed(:final usernames) => [
      if (after == null)
        for (final u in usernames)
          _userPostsUri(u, sort: sort, topTime: topTime),
    ],
  };

  Future<List<RedditPost>> _getListing(Uri uri) =>
      _withCache<List<RedditPost>>(
        bucket: CacheBucket.postList,
        uri: uri,
        parse: RedditPost.parseListing,
      );

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

  Future<CommentsPage> getComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
    String? permalink,
    String? context,
  }) => _withCache<CommentsPage>(
    bucket: CacheBucket.comments,
    uri: _commentsUri(
      subreddit,
      postId,
      sort: sort,
      permalink: permalink,
      context: context,
    ),
    parse: (doc) => CommentsPage.fromDocument(doc, subreddit, postId),
  );

  /// Re-fetch a placeholder's thread (the morechildren JSON API is blocked); null when the fetch fails.
  Future<List<RedditComment>?> loadMoreComments({
    required String permalink,
    required String parentFullname,
    String sort = SortConstants.confidence,
  }) => _fetchAndParse<List<RedditComment>>(
    moreCommentsUri(permalink, sort),
    (doc) => RedditComment.parseCommentArea(doc, permalink, parentFullname),
  );

  /// The thread, subreddit or user [link] stands for; null when reddit does not name one.
  Future<RedditLink?> resolveShareLink(ShareLink link) async {
    final target = await RequestPipeline.instance.getRedirect(link.uri);
    final resolved = target == null ? null : RedditLink.parse(target.toString());
    return resolved is ShareLink ? null : resolved;
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

  /// Subreddit search uses new reddit's community endpoint: old.reddit's search
  /// page carries neither member counts nor icons, and reddit no longer exposes
  /// subscriber counts on old.reddit at all. The session (sent on every request)
  /// clears new reddit's verification wall. Ranked by weekly visitors, highest
  /// first.
  Future<List<Subreddit>> searchSubreddits(String query) {
    final uri = Uri.https('www.reddit.com', '/search/', {
      'q': query,
      'type': 'communities',
    });
    return _withCache<List<Subreddit>>(
      bucket: CacheBucket.subredditSearch,
      uri: uri,
      parse: Subreddit.parseSearchResults,
    );
  }

  RedditUser? peekUserInfo(String username) =>
      _peek<RedditUser>(CacheBucket.userInfo, _userInfoUri(username));

  CommentsPage? peekComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
    String? permalink,
    String? context,
  }) => _peek<CommentsPage>(
    CacheBucket.comments,
    _commentsUri(
      subreddit,
      postId,
      sort: sort,
      permalink: permalink,
      context: context,
    ),
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

  /// A comments page, by permalink when known: the slugless path redirects to a slug URL the HTTP client cannot follow when the title is non-ASCII.
  Uri _commentsUri(
    String subreddit,
    String postId, {
    required String sort,
    String? permalink,
    String? context,
  }) => Uri.https(
    _host,
    permalink == null || permalink.isEmpty
        ? '/r/$subreddit/comments/$postId/'
        : permalink,
    {'sort': sort, 'context': ?context},
  );

  /// The fetch URL for expanding a "more comments" placeholder. [permalink] is a
  /// full URL; Uri.parse already normalizes a raw non-ASCII path to its
  /// percent-encoded form, so only the query is replaced. Rebuilding from
  /// base.path would double-encode (%C3%BC -> %25C3%25BC) and 404 the thread.
  @visibleForTesting
  Uri moreCommentsUri(String permalink, String sort) {
    final base = Uri.parse(permalink);
    return base.replace(
      queryParameters: {...base.queryParameters, 'sort': sort},
    );
  }

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
      return await Isolate.run(() => parse(html_parser.parse(body)));
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'reddit_service',
        context: ErrorDescription('while parsing $uri'),
      ));
      return null;
    }
  }

  void cacheExpandedComments(
    String subreddit,
    String postId,
    String sort,
    CommentsPage page, {
    String? permalink,
    String? context,
  }) {
    RedditCache.instance.put(
      _commentsUri(
        subreddit,
        postId,
        sort: sort,
        permalink: permalink,
        context: context,
      ).toString(),
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
