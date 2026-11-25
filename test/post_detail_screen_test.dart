import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/models/comments_page.dart';
import 'package:reddlit/models/reddit_comment.dart';
import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/screens/post_detail_screen.dart';
import 'package:reddlit/services/reddit_service.dart';
import 'package:reddlit/utils/reddit_link.dart';

RedditPost _post(String id) => RedditPost(
      id: id,
      title: 'T',
      author: 'u',
      subreddit: 's',
      score: 1,
      numComments: 3,
      created: DateTime(2020),
      isVideo: false,
      domain: 'self.s',
    );

// Every request fails; the pipeline singleton binds this client on first use.
http.Client _failing() => MockClient((_) async => http.Response('', 404));

void main() {
  testWidgets('a failed comment load offers retry, not "No comments yet"',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: PostDetailScreen(post: _post('p1'))));
      await tester.pumpAndSettle();
      expect(find.text('No comments yet'), findsNothing);
      expect(find.text('Failed to load comments.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }, _failing);
  });

  testWidgets('a failed "load more" keeps the placeholder, tappable and cached',
      (tester) async {
    final post = _post('p2');
    final placeholder = RedditComment(
      id: 'more_t1_c1_5',
      author: '',
      body: '',
      score: 0,
      created: DateTime(2020),
      depth: 1,
      parentId: 't1_c1',
      isMorePlaceholder: true,
      replyCount: 5,
      morePermalink: 'https://old.reddit.com/r/s/comments/p2/t/c1/',
    );
    final thread = RedditComment(
      id: 'c1',
      author: 'a',
      body: 'top comment',
      score: 1,
      created: DateTime(2020),
      depth: 0,
      parentId: 't3_p2',
      replies: [placeholder],
    );
    final service = RedditService();
    service.cacheExpandedComments(
        's', 'p2', 'confidence', CommentsPage(post: post, comments: [thread]));

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: PostDetailScreen(post: post)));
      await tester.pump();
      await tester.tap(find.text('Load 5 more replies'));
      await tester.pumpAndSettle();
      expect(find.text('Load 5 more replies'), findsOneWidget);
      final cached = service.peekComments('s', 'p2')!.comments.single;
      expect(cached.replies.single.id, placeholder.id);
    }, _failing);
  });

  testWidgets('a comment link shows that thread, then the whole post on request',
      (tester) async {
    final link = RedditLink.parse(
        'https://www.reddit.com/r/s/comments/p3/t/c9/?context=3')! as ThreadLink;
    final post = RedditPost(
      id: 'p3',
      title: 'Cited post',
      author: 'u',
      subreddit: 's',
      score: 1,
      numComments: 2,
      created: DateTime(2020),
      permalink: '/r/s/comments/p3/t/',
      isVideo: false,
      domain: 'self.s',
    );
    RedditComment comment(String id) => RedditComment(
          id: id,
          author: 'a',
          body: 'body $id',
          score: 1,
          created: DateTime(2020),
          depth: 0,
        );
    // Seeded under the exact page each view requests.
    RedditService()
      ..cacheExpandedComments(
        's',
        'p3',
        'confidence',
        CommentsPage(post: post, comments: [comment('c9')]),
        permalink: '/r/s/comments/p3/t/c9/',
        context: '3',
      )
      ..cacheExpandedComments(
        's',
        'p3',
        'confidence',
        CommentsPage(post: post, comments: [comment('c1'), comment('c9')]),
        permalink: '/r/s/comments/p3/t/',
      );

    await http.runWithClient(() async {
      await tester.pumpWidget(
          MaterialApp(home: PostDetailScreen.fromLink(link)));
      await tester.pump();
      expect(find.text('Cited post'), findsOneWidget);
      expect(find.text('body c9'), findsOneWidget);
      expect(find.text('body c1'), findsNothing);

      await tester.tap(find.text('View all comments'));
      await tester.pump();
      await tester.pump();
      expect(find.text('body c1'), findsOneWidget);
      expect(find.text('Single comment thread'), findsNothing);
    }, _failing);
  });
}
