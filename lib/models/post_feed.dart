import 'reddit_post.dart';

/// What a post list shows; one value derives both its fetch and its cache peek.
sealed class PostFeed {
  const PostFeed();
}

final class FrontpageFeed extends PostFeed {
  const FrontpageFeed();
}

/// One subreddit, or several as a multireddit; no names lists nothing.
final class SubredditsFeed extends PostFeed {
  final List<String> names;
  const SubredditsFeed(this.names);
}

final class UserFeed extends PostFeed {
  final String username;
  const UserFeed(this.username);
}

/// Several users' submissions; each page merges the next page of every user who has more.
final class FollowingFeed extends PostFeed {
  final List<String> usernames;
  const FollowingFeed(this.usernames);
}

/// Where a feed continues: the last post fullname of each listing it reads that has more.
typedef FeedCursor = Map<String, String>;

/// One page of a feed; [next] is null once every listing has ended.
class PostPage {
  final List<RedditPost> posts;
  final FeedCursor? next;
  const PostPage(this.posts, this.next);
}
