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

/// Several users' submissions merged into one unpaginated list.
final class FollowingFeed extends PostFeed {
  final List<String> usernames;
  const FollowingFeed(this.usernames);
}
