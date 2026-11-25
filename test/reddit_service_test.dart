import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/models/post_feed.dart';
import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/services/reddit_cache.dart';
import 'package:reddlit/services/reddit_service.dart';
import 'package:reddlit/utils/reddit_link.dart';

RedditPost _post(String id, {DateTime? created, int score = 0}) => RedditPost(
      id: id,
      title: id,
      author: 'u',
      subreddit: 's',
      score: score,
      numComments: 0,
      created: created ?? DateTime(2020),
      isVideo: false,
      domain: 'self.s',
    );

List<String> _ids(List<RedditPost> posts) => [for (final p in posts) p.id];

void main() {
  // The RequestPipeline singleton takes its client from this zone on first use.
  test('each fetch path parses the page it is served', () async {
    const pages = {
      '/hot/': 'listing-posts.html',
      '/r/x/comments/y/': 'comments.html',
      '/user/spez/': 'user-profile.html',
      '/search/': 'community-search.html',
      '/r/x/comments/y/z/abc/': 'comments.html',
    };
    await http.runWithClient(
      () async {
        final service = RedditService();
        expect(await service.getPosts(const FrontpageFeed()), hasLength(3));
        expect((await service.getComments('x', 'y')).comments, isNotEmpty);
        expect((await service.getUserInfo('spez')).linkKarma, 183996);
        expect(await service.searchSubreddits('cats'), hasLength(3));
        expect(
          await service.loadMoreComments(
            permalink: 'https://old.reddit.com/r/x/comments/y/z/abc/',
            parentFullname: 't3_y',
          ),
          isNotEmpty,
        );
        expect(
          await service.loadMoreComments(
            permalink: 'https://old.reddit.com/r/x/comments/gone/',
            parentFullname: 't3_x',
          ),
          isNull,
        );
        final shared = await service.resolveShareLink(
          RedditLink.parse('https://www.reddit.com/r/x/s/tok')! as ShareLink,
        );
        expect((shared! as ThreadLink).commentId, 'abc');
      },
      () => MockClient((request) async {
        if (request.url.path == '/r/x/s/tok') {
          return http.Response('', 301, headers: {
            'location': 'https://www.reddit.com/r/x/comments/y/z/abc/?share_id=1',
          });
        }
        final page = pages[request.url.path];
        if (page == null) return http.Response('', 404);
        return http.Response.bytes(
          File('test/fixtures/$page').readAsBytesSync(),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
  });

  // A post list is cached under its request URI, so a seeded entry answering
  // both the fetch and the peek proves the exact URI each feed requests.
  group('post feed request URIs', () {
    final service = RedditService();

    List<RedditPost> seed(String uri, [List<RedditPost>? posts]) {
      final value = posts ?? [_post(uri)];
      RedditCache.instance.put(uri, value);
      return value;
    }

    test('frontpage, with after and top time', () async {
      const feed = FrontpageFeed();
      final page1 = seed('https://old.reddit.com/rising/');
      expect(service.peekPosts(feed, sort: 'rising'), same(page1));
      expect(await service.getPosts(feed, sort: 'rising'), same(page1));
      final page2 = seed('https://old.reddit.com/top/?after=t3_x&t=week');
      expect(
        await service.getPosts(feed, sort: 'top', topTime: 'week', after: 't3_x'),
        same(page2),
      );
    });

    test('one subreddit and a multireddit', () async {
      final all = seed('https://old.reddit.com/r/all/new/');
      expect(service.peekPosts(const SubredditsFeed(['all']), sort: 'new'),
          same(all));
      expect(await service.getPosts(const SubredditsFeed(['all']), sort: 'new'),
          same(all));
      const multiFeed = SubredditsFeed(['a', 'b']);
      final multi = seed('https://old.reddit.com/r/a+b/controversial/');
      expect(service.peekPosts(multiFeed, sort: 'controversial'), same(multi));
      expect(await service.getPosts(multiFeed, sort: 'controversial'),
          same(multi));
    });

    test('a multireddit of no subreddits lists nothing', () async {
      expect(service.peekPosts(const SubredditsFeed([])), isNull);
      expect(await service.getPosts(const SubredditsFeed([])), isEmpty);
    });

    test('user submissions carry no sort', () async {
      const feed = UserFeed('someone');
      final user = seed('https://old.reddit.com/user/someone/submitted/');
      expect(service.peekPosts(feed), same(user));
      expect(await service.getPosts(feed), same(user));
      final next =
          seed('https://old.reddit.com/user/someone/submitted/?after=t3_y');
      expect(await service.getPosts(feed, after: 't3_y'), same(next));
    });

    test('following merges user streams, newest first under new', () async {
      const feed = FollowingFeed(['u1', 'u2']);
      seed('https://old.reddit.com/user/u1/submitted/?sort=new',
          [_post('older', created: DateTime(2020))]);
      seed('https://old.reddit.com/user/u2/submitted/?sort=new',
          [_post('newer', created: DateTime(2021))]);
      expect(_ids(service.peekPosts(feed, sort: 'new')!), ['newer', 'older']);
      expect(_ids(await service.getPosts(feed, sort: 'new')),
          ['newer', 'older']);
    });

    test('following under top merges by score and sends t', () async {
      const feed = FollowingFeed(['u3', 'u4']);
      seed('https://old.reddit.com/user/u3/submitted/?sort=top&t=day',
          [_post('low', score: 1)]);
      seed('https://old.reddit.com/user/u4/submitted/?sort=top&t=day',
          [_post('high', score: 9)]);
      expect(_ids(service.peekPosts(feed, sort: 'top', topTime: 'day')!),
          ['high', 'low']);
      expect(_ids(await service.getPosts(feed, sort: 'top', topTime: 'day')),
          ['high', 'low']);
    });

    test('following nobody lists nothing', () async {
      expect(service.peekPosts(const FollowingFeed([])), isNull);
      expect(await service.getPosts(const FollowingFeed([])), isEmpty);
    });

    test('following has no further pages', () async {
      expect(
        await service.getPosts(const FollowingFeed(['u1']), after: 't3_z'),
        isEmpty,
      );
    });
  });
}
