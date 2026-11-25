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

  /// The first page of [feed], or the page [after] continues; throws when no listing could be read.
  Future<PostPage> getPosts(
    PostFeed feed, {
    String sort = SortConstants.hot,
    String? topTime,
    FeedCursor? after,
  }) async {
    final uris = _feedUris(feed, sort: sort, topTime: topTime, after: after);
    if (uris.isEmpty) return const PostPage([], null);

    // One failed listing must not empty a feed merged from several.
    final pages = await Future.wait([
      for (final uri in uris.values)
        _getListing(uri).then<List<RedditPost>?>((p) => p, onError: (_) => null),
    ]);
    final read = pages.nonNulls.toList();
    if (read.isEmpty) {
      throw const RedditServiceException('Network request failed.');
    }
    final next = <String, String>{
      for (final (i, listing) in uris.keys.indexed)
        if (pages[i]?.lastOrNull case final last?) listing: 't3_${last.id}',
    };
    return PostPage(
      read.length == 1 ? read.single : _mergePosts(read, sort),
      next.isEmpty ? null : next,
    );
  }

  List<RedditPost>? peekPosts(
    PostFeed feed, {
    String sort = SortConstants.hot,
    String? topTime,
  }) {
    final streams = _feedUris(feed, sort: sort, topTime: topTime)
        .values
        .map(_peek<List<RedditPost>>)
        .nonNulls
        .toList();
    if (streams.isEmpty) return null;
    return streams.length == 1 ? streams.single : _mergePosts(streams, sort);
  }

  /// The listings [feed] reads, by name: one, or one per followed user. With [after], only the listings it continues.
  Map<String, Uri> _feedUris(
    PostFeed feed, {
    required String sort,
    String? topTime,
    FeedCursor? after,
  }) => switch (feed) {
    FrontpageFeed() => {
      '': _postsUri('', sort: sort, after: after?[''], topTime: topTime),
    },
    SubredditsFeed(:final names) => {
      if (names.isNotEmpty)
        '': _postsUri(
          '/r/${names.join('+')}',
          sort: sort,
          after: after?[''],
          topTime: topTime,
        ),
    },
    UserFeed(:final username) => {
      '': _userPostsUri(username, after: after?['']),
    },
    FollowingFeed(:final usernames) => {
      for (final u in usernames)
        if (after == null || after.containsKey(u))
          u: _userPostsUri(u, sort: sort, topTime: topTime, after: after?[u]),
    },
  };

  Future<List<RedditPost>> _getListing(Uri uri) =>
      _fetchAndRemember<List<RedditPost>>(uri, RedditPost.parseListing);

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
  }) => _fetchAndRemember<CommentsPage>(
    _commentsUri(
      subreddit,
      postId,
      sort: sort,
      permalink: permalink,
      context: context,
    ),
    (doc) => CommentsPage.fromDocument(doc, subreddit, postId),
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

  /// The user's profile; on failure the last one read, or an empty one.
  Future<RedditUser> getUserInfo(String username) async {
    try {
      return await _fetchAndRemember<RedditUser>(
        _userInfoUri(username),
        (doc) => RedditUser.fromUserPage(doc, username),
      );
    } on RedditServiceException {
      return peekUserInfo(username) ?? RedditUser.empty(username);
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
    return _fetch<List<Subreddit>>(uri, Subreddit.parseSearchResults);
  }

  RedditUser? peekUserInfo(String username) =>
      _peek<RedditUser>(_userInfoUri(username));

  CommentsPage? peekComments(
    String subreddit,
    String postId, {
    String sort = SortConstants.confidence,
    String? permalink,
    String? context,
  }) => _peek<CommentsPage>(
    _commentsUri(
      subreddit,
      postId,
      sort: sort,
      permalink: permalink,
      context: context,
    ),
  );

  T? _peek<T>(Uri uri) => RedditCache.instance.lookup<T>(uri.toString());

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

  /// [_fetch], remembered so a revisit can show the page at once while it reloads.
  Future<T> _fetchAndRemember<T extends Object>(
    Uri uri,
    T Function(Document doc) parse,
  ) async {
    final fresh = await _fetch<T>(uri, parse);
    RedditCache.instance.put(uri.toString(), fresh);
    return fresh;
  }

  /// The parsed page at [uri]; throws when the request or the parse fails.
  Future<T> _fetch<T>(Uri uri, T Function(Document doc) parse) async {
    final fresh = await _fetchAndParse<T>(uri, parse);
    if (fresh == null) {
      throw const RedditServiceException('Network request failed.');
    }
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
