import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../screens/subreddit_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/reddit_service.dart';

/// Centralized navigation + predictive prefetch.
///
/// Every navigate-to-X call also warms X's cache before the route builds.
/// By the time the destination screen's `initState` peeks the cache, the
/// fetch is often already in flight or complete — the user sees content
/// with no spinner.
class NavigationHelper {
  const NavigationHelper._();

  static void navigateToSubreddit(BuildContext context, String subreddit) {
    RedditService().prefetchSubredditPosts(subreddit);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubredditScreen(subreddit: subreddit),
      ),
    );
  }

  static void navigateToUser(BuildContext context, String username) {
    final svc = RedditService();
    svc.prefetchUserInfo(username);
    svc.prefetchUserPosts(username);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(username: username),
      ),
    );
  }

  static void navigateToPost(BuildContext context, RedditPost post) {
    RedditService().prefetchComments(post.subreddit, post.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }
}
