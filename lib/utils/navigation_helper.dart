import 'package:material_ui/material_ui.dart';
import '../models/reddit_post.dart';
import '../screens/subreddit_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/reddit_service.dart';
import 'reddit_link.dart';
import 'url_utils.dart';

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

  static Future<void> openLink(BuildContext context, RedditLink link) async {
    switch (link) {
      case ThreadLink():
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen.fromLink(link),
          ),
        );
      case SubredditLink(:final name):
        navigateToSubreddit(context, name);
      case UserLink(:final name):
        navigateToUser(context, name);
      case ShareLink(:final uri):
        final messenger = ScaffoldMessenger.of(context)
          ..showSnackBar(const SnackBar(content: Text('Opening shared link…')));
        final target = await RedditService().resolveShareLink(link);
        messenger.hideCurrentSnackBar();
        if (!context.mounted) return;
        if (target == null) {
          UrlUtils.openUrl(uri.toString());
        } else {
          openLink(context, target);
        }
    }
  }

  /// Reddit threads, subreddits and users open in the app; anything else in the browser.
  static void openUrl(BuildContext context, String url) {
    final link = RedditLink.parse(url);
    if (link == null) {
      UrlUtils.openUrl(url);
    } else {
      openLink(context, link);
    }
  }
}
