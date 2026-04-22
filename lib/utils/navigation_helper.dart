import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../screens/subreddit_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';

class NavigationHelper {
  const NavigationHelper._();

  static void navigateToSubreddit(BuildContext context, String subreddit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubredditScreen(subreddit: subreddit),
      ),
    );
  }

  static void navigateToUser(BuildContext context, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(username: username),
      ),
    );
  }

  static void navigateToPost(BuildContext context, RedditPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }
}
