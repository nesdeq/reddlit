import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reddlit/models/post_feed.dart';
import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/widgets/post_list_mixin.dart';

RedditPost _post(String id) => RedditPost(
      id: id,
      title: id,
      author: 'u',
      subreddit: 's',
      score: 0,
      numComments: 0,
      created: DateTime(2020),
      isVideo: false,
      domain: 'self.s',
    );

/// A page of one post that says where it continues.
PostPage _page(String id) => PostPage([_post(id)], {'': 't3_$id'});

class _Feed extends StatefulWidget {
  const _Feed();

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> with PostListMixin {
  final replies = <Completer<PostPage>>[];
  final afters = <FeedCursor?>[];

  @override
  PostFeed get feed => const FrontpageFeed();

  @override
  Future<PostPage> loadPostsImplementation({FeedCursor? after}) {
    afters.add(after);
    return (replies..add(Completer())).last.future;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  Future<_FeedState> mount(WidgetTester tester) async {
    await tester.pumpWidget(const _Feed());
    return tester.state<_FeedState>(find.byType(_Feed));
  }

  List<String> ids(List<RedditPost> posts) => [for (final p in posts) p.id];

  testWidgets('a reload during the first load supersedes it', (tester) async {
    final feed = await mount(tester);
    unawaited(feed.loadPosts());
    feed.clearAndReload();
    expect(feed.replies, hasLength(2));

    feed.replies[0].complete(_page('stale'));
    await tester.pump();
    expect(feed.posts, isEmpty);

    feed.replies[1].complete(_page('fresh'));
    await tester.pump();
    expect(ids(feed.posts), ['fresh']);
    expect(feed.isLoading, isFalse);
  });

  testWidgets('a reload during load-more drops the stale page', (tester) async {
    final feed = await mount(tester);
    unawaited(feed.loadPosts());
    feed.replies[0].complete(_page('p1'));
    await tester.pump();

    unawaited(feed.loadMorePosts());
    expect(feed.afters.last, {'': 't3_p1'});
    feed.clearAndReload();
    expect(feed.replies, hasLength(3));

    feed.replies[1].complete(_page('stale2'));
    await tester.pump();
    feed.replies[2].complete(_page('new1'));
    await tester.pump();
    expect(ids(feed.posts), ['new1']);
    expect(feed.isLoading, isFalse);
  });

  testWidgets('load-more leaves the fetched page list untouched', (tester) async {
    final feed = await mount(tester);
    final page1 = _page('p1');
    unawaited(feed.loadPosts());
    feed.replies[0].complete(page1);
    await tester.pump();

    unawaited(feed.loadMorePosts());
    feed.replies[1].complete(_page('p2'));
    await tester.pump();
    expect(ids(feed.posts), ['p1', 'p2']);
    expect(ids(page1.posts), ['p1']);
  });

  testWidgets('each page continues from the cursor the last one gave, until none',
      (tester) async {
    final feed = await mount(tester);
    unawaited(feed.loadPosts());
    feed.replies[0].complete(PostPage([_post('p1')], {'a': 't3_p1', 'b': 't3_x'}));
    await tester.pump();

    unawaited(feed.loadMorePosts());
    expect(feed.afters.last, {'a': 't3_p1', 'b': 't3_x'});
    feed.replies[1].complete(PostPage([_post('p2')], {'b': 't3_p2'}));
    await tester.pump();
    expect(feed.hasMore, isTrue);

    unawaited(feed.loadMorePosts());
    expect(feed.afters.last, {'b': 't3_p2'});
    feed.replies[2].complete(PostPage([_post('p3')], null));
    await tester.pump();
    expect(ids(feed.posts), ['p1', 'p2', 'p3']);
    expect(feed.hasMore, isFalse);

    unawaited(feed.loadMorePosts());
    expect(feed.replies, hasLength(3));
  });
}
