import 'package:html/dom.dart';

import 'reddit_comment.dart';
import 'reddit_post.dart';

/// A post page: the post with its selftext/gallery (absent from listings) and comment tree.
class CommentsPage {
  final RedditPost? post;
  final List<RedditComment> comments;
  const CommentsPage({this.post, this.comments = const []});

  factory CommentsPage.fromDocument(
    Document doc,
    String subreddit,
    String postId,
  ) {
    final postThing = doc.querySelector('#siteTable div.thing');
    final post = (postThing != null &&
            (postThing.attributes['data-fullname'] ?? '').startsWith('t3_'))
        ? RedditPost.fromThing(postThing)
        : null;
    final permalink = postThing?.attributes['data-permalink'] ??
        '/r/$subreddit/comments/$postId/';
    return CommentsPage(
      post: post,
      comments: RedditComment.parseCommentArea(doc, permalink, 't3_$postId'),
    );
  }
}
