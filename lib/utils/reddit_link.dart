import '../constants/sort_constants.dart';

/// A reddit URL the app can show itself.
sealed class RedditLink {
  const RedditLink();

  /// Null for anything that is not an in-app destination.
  static RedditLink? parse(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    final host = uri.host.toLowerCase();
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    } on ArgumentError {
      return null;
    }

    if (host == 'redd.it') {
      return segments.length == 1 && _id.hasMatch(segments[0])
          ? ThreadLink._(postId: segments[0], segments: ['comments', segments[0]])
          : null;
    }
    final onReddit = host.isEmpty
        ? url.trim().startsWith('/')
        : host == 'reddit.com' || host.endsWith('.reddit.com');
    if (!onReddit) return null;

    switch (segments) {
      case [
            ('r' || 'u' || 'user') && final kind,
            final owner,
            'comments',
            final id,
            ...final slugAndComment,
          ]
          when _id.hasMatch(id) &&
              (kind == 'r' ? _subreddit : _user).hasMatch(owner):
        final commentId = slugAndComment.elementAtOrNull(1);
        final focused = commentId != null && _id.hasMatch(commentId);
        return ThreadLink._(
          subreddit: kind == 'r' ? owner : null,
          postId: id,
          commentId: focused ? commentId : null,
          context: focused ? uri.queryParameters['context'] : null,
          segments: [
            kind == 'r' ? 'r' : 'user',
            owner,
            'comments',
            id,
            ...slugAndComment.take(focused ? 2 : 1),
          ],
        );
      case [('r' || 'u' || 'user') && final kind, final owner, 's', final token]
          when _id.hasMatch(token) &&
              (kind == 'r' ? _subreddit : _user).hasMatch(owner):
        return ShareLink(Uri.https('www.reddit.com', '/$kind/$owner/s/$token'));
      case ['comments' || 'gallery', final id, ...] when _id.hasMatch(id):
        return ThreadLink._(postId: id, segments: ['comments', id]);
      case ['r', final sub] when _subreddit.hasMatch(sub):
        return SubredditLink(sub);
      case ['r', final sub, final sort]
          when _subreddit.hasMatch(sub) &&
              SortConstants.postSortLabels.containsKey(sort):
        return SubredditLink(sub);
      case ['u' || 'user', final name] when _user.hasMatch(name):
        return UserLink(name);
      default:
        return null;
    }
  }

  static final _id = RegExp(r'^[A-Za-z0-9]+$');
  static final _subreddit = RegExp(r'^[A-Za-z0-9_+]+$');
  static final _user = RegExp(r'^[A-Za-z0-9_-]+$');
}

/// A post's comment page, or one comment's thread within it when [commentId] is set.
final class ThreadLink extends RedditLink {
  final String postId;
  final String? subreddit;
  final String? commentId;

  /// Reddit's `context` query: how many parent comments to show above [commentId].
  final String? context;

  /// Decoded page path, as old.reddit's `data-permalink` gives it.
  final String path;

  ThreadLink._({
    required this.postId,
    required List<String> segments,
    this.subreddit,
    this.commentId,
    this.context,
  }) : path = '/${segments.join('/')}/';
}

/// A share link (`/r/<sub>/s/<token>`): reddit names its target only in the redirect [uri] answers with.
final class ShareLink extends RedditLink {
  final Uri uri;
  const ShareLink(this.uri);
}

final class SubredditLink extends RedditLink {
  final String name;
  const SubredditLink(this.name);
}

final class UserLink extends RedditLink {
  final String name;
  const UserLink(this.name);
}
