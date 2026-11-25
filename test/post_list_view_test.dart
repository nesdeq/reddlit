import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/widgets/post_card.dart';
import 'package:reddlit/widgets/post_list_view.dart';

RedditPost _post(String id) => RedditPost(
      id: id,
      title: 'title $id',
      author: 'u',
      subreddit: 's',
      score: 0,
      numComments: 0,
      created: DateTime(2020),
      isVideo: false,
      domain: 'self.s',
    );

Future<void> _show(
  WidgetTester tester, {
  List<RedditPost> posts = const [],
  bool isLoading = false,
  bool hasMore = true,
  String? error,
  Widget? header,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PostListView(
        header: header,
        posts: posts,
        isLoading: isLoading,
        hasMore: hasMore,
        errorMessage: error,
        scrollController: ScrollController(),
        onRefresh: () async {},
        onRetry: () async {},
      ),
    ),
  ));
}

void main() {
  testWidgets('first page loading: spinner only', (tester) async {
    await _show(tester, isLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(PostCard), findsNothing);
  });

  testWidgets('first page failed: message with retry', (tester) async {
    await _show(tester, error: 'Failed to load posts.');
    expect(find.text('Failed to load posts.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('loaded, no more pages: cards then the end marker', (tester) async {
    await _show(tester, posts: [_post('a'), _post('b')], hasMore: false);
    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.text('No more posts'), findsOneWidget);
  });

  testWidgets('loading the next page: cards then a spinner', (tester) async {
    await _show(tester, posts: [_post('a')], isLoading: true);
    expect(find.byType(PostCard), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty first page says so', (tester) async {
    await _show(tester, hasMore: false);
    expect(find.text('No posts yet'), findsOneWidget);
  });

  group('with a header', () {
    const header = Text('HEADER');

    testWidgets('first page loading: header above a spinner', (tester) async {
      await _show(tester, header: header, isLoading: true);
      expect(find.text('HEADER'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('first page failed: header above retry', (tester) async {
      await _show(tester, header: header, error: 'Failed to load posts.');
      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('Failed to load posts.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('loaded: header, cards, end marker', (tester) async {
      await _show(tester, header: header, posts: [_post('a')], hasMore: false);
      expect(find.text('HEADER'), findsOneWidget);
      expect(find.byType(PostCard), findsOneWidget);
      expect(find.text('No more posts'), findsOneWidget);
    });
  });
}
