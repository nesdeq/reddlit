import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reddit_post.dart';
import '../models/reddit_comment.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import '../constants/http_constants.dart';

class RedditService {
  static final http.Client _client = http.Client();

  static const Map<String, String> _headers = HttpConstants.browserHeaders;

  Future<List<RedditPost>> getFrontpage({
    String sort = 'hot',
    String? after,
    String? topTime, // For top sorting: hour, day, week, month, year, all
  }) async {
    return _getPosts('', sort: sort, after: after, topTime: topTime);
  }

  Future<List<RedditPost>> getSubredditPosts(
    String subreddit, {
    String sort = 'hot',
    String? after,
    String? topTime, // For top sorting: hour, day, week, month, year, all
  }) async {
    return _getPosts('/r/$subreddit', sort: sort, after: after, topTime: topTime);
  }

  /// Get posts from multiple subreddits (personal selection from favorites)
  /// Uses Reddit's multireddit syntax: /r/sub1+sub2+sub3
  Future<List<RedditPost>> getPersonalPosts(
    List<String> subreddits, {
    String sort = 'hot',
    String? after,
    String? topTime,
  }) async {
    if (subreddits.isEmpty) {
      return [];
    }

    // Join subreddits with '+' for Reddit's multireddit syntax
    final multireddit = subreddits.join('+');
    return _getPosts('/r/$multireddit', sort: sort, after: after, topTime: topTime);
  }

  Future<List<RedditPost>> getUserPosts(
    String username, {
    String? after,
  }) async {
    try {
      final uri = Uri.https(
        'www.reddit.com',
        '/user/$username/submitted.json',
        after != null ? {'after': after} : null,
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final children = data['data']['children'] as List;
        return children
            .where((child) => child['kind'] == 't3')
            .map((child) => RedditPost.fromJson(child))
            .toList();
      }
      return [];
    } catch (e) {
      return _handleError<List<RedditPost>>('user posts', e, []);
    }
  }

  Future<List<RedditPost>> _getPosts(
    String path, {
    required String sort,
    String? after,
    String? topTime,
  }) async {
    try {
      // Build query parameters efficiently using Map
      final queryParams = <String, String>{};
      if (after != null) queryParams['after'] = after;
      if (sort == 'top' && topTime != null) queryParams['t'] = topTime;

      // Use Uri.https for safe and efficient URL construction
      final uri = Uri.https(
        'www.reddit.com',
        '$path/$sort.json',
        queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final children = data['data']['children'] as List;
        return children
            .where((child) => child['kind'] == 't3')
            .map((child) => RedditPost.fromJson(child))
            .toList();
      }
      return [];
    } catch (e) {
      return _handleError<List<RedditPost>>('posts', e, []);
    }
  }

  Future<List<RedditComment>> getComments(
    String subreddit,
    String postId, {
    String sort = 'confidence', // 'confidence' = Best on Reddit
  }) async {
    try {
      final uri = Uri.https(
        'www.reddit.com',
        '/r/$subreddit/comments/$postId.json',
        {'sort': sort},
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.length > 1) {
          final commentsData = data[1]['data']['children'] as List;
          return commentsData
              .where((child) => child['kind'] == 't1')
              .map((child) => RedditComment.fromJson(child))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return _handleError<List<RedditComment>>('comments', e, []);
    }
  }

  Future<RedditUser> getUserInfo(String username) async {
    try {
      final uri = Uri.https('www.reddit.com', '/user/$username/about.json');
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RedditUser.fromJson(data);
      }
      return RedditUser.empty(username);
    } catch (e) {
      return _handleError<RedditUser>('user info', e, RedditUser.empty(username));
    }
  }

  /// Search for subreddits where NAME contains the query, sorted by subscriber count (descending)
  Future<List<Subreddit>> searchSubreddits(String query) async {
    try {
      final uri = Uri.https(
        'www.reddit.com',
        '/subreddits/search.json',
        {'q': query, 'limit': '100', 'include_over_18': 'on'},
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final children = data['data']['children'] as List;

        final queryLower = query.toLowerCase();
        final subreddits = children
            .where((child) => child['kind'] == 't5')
            .map((child) => Subreddit.fromJson(child))
            // FILTER: Only include if subreddit name contains the search query
            .where((subreddit) => subreddit.displayName.toLowerCase().contains(queryLower))
            .toList();

        // Sort by subscriber count (descending)
        subreddits.sort((a, b) => b.subscribers.compareTo(a.subscribers));

        return subreddits;
      }
      return [];
    } catch (e) {
      return _handleError<List<Subreddit>>('subreddits', e, []);
    }
  }

  /// Centralized error handler with fallback values
  T _handleError<T>(String operation, Object error, T fallback) => fallback;
}
