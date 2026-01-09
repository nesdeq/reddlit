import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../screens/subreddit_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';

/// Centralized navigation helpers to eliminate duplicate navigation code
class NavigationHelper {
  const NavigationHelper._(); // Private constructor to prevent instantiation
  /// Navigate to a subreddit screen
  static void navigateToSubreddit(BuildContext context, String subreddit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubredditScreen(subreddit: subreddit),
      ),
    );
  }

  /// Navigate to a user profile screen
  static void navigateToUser(BuildContext context, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(username: username),
      ),
    );
  }

  /// Navigate to a post detail screen
  static void navigateToPost(BuildContext context, RedditPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }
}
