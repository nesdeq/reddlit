import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/models/post_feed.dart';
import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/services/reddit_service.dart';
import 'package:reddlit/utils/reddit_link.dart';

const _fixtures = {
  '/hot/': 'listing-posts.html',
  '/r/x/comments/y/': 'comments.html',
  '/user/spez/': 'user-profile.html',
  '/search/': 'community-search.html',
  '/r/x/comments/y/z/abc/': 'comments.html',
};

/// Listing pages by full URL, set by each test; any other URL answers 404.
final _served = <String, String>{};
final _requested = <String>[];
var _offline = false;

// The RequestPipeline singleton takes its client from the first zone that uses it.
http.Client _client() => MockClient((request) async {
      final url = request.url.toString();
      _requested.add(url);
      if (_offline) return http.Response('', 404);
      if (request.url.path == '/r/x/s/tok') {
        return http.Response('', 301, headers: {
          'location': 'https://www.reddit.com/r/x/comments/y/z/abc/?share_id=1',
        });
      }
      const html = {'content-type': 'text/html; charset=utf-8'};
      final listing = _served[url];
      if (listing != null) return http.Response(listing, 200, headers: html);
      final fixture = _fixtures[request.url.path];
      if (fixture == null) return http.Response('', 404);
      return http.Response.bytes(
        File('test/fixtures/$fixture').readAsBytesSync(),
        200,
        headers: html,
      );
    });

Future<void> _online(Future<void> Function() body) =>
    http.runWithClient(body, _client);

String _thing(String id, {int score = 0, int year = 2020}) =>
    '<div class="thing" data-fullname="t3_$id" data-author="u" '
    'data-subreddit="s" data-domain="self.s" data-score="$score" '
    'data-comments-count="0" '
    'data-timestamp="${DateTime(year).millisecondsSinceEpoch}">'
    '<a class="title">$id</a></div>';

void _serve(String url, List<String> things) =>
    _served[url] = '<div id="siteTable">${things.join()}</div>';

List<String> _ids(List<RedditPost> posts) => [for (final p in posts) p.id];

void main() {
  final service = RedditService();

  setUp(() {
    _served.clear();
    _requested.clear();
    _offline = false;
  });

  test('each fetch path parses the page it is served', () => _online(() async {
        final frontpage = await service.getPosts(const FrontpageFeed());
        expect(frontpage.posts, hasLength(3));
        expect(frontpage.next, {'': 't3_${frontpage.posts.last.id}'});
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
      }));

  test('a page is fetched again on every visit and remembered for the next',
      () => _online(() async {
            const url = 'https://old.reddit.com/r/fresh/hot/';
            const feed = SubredditsFeed(['fresh']);
            expect(service.peekPosts(feed), isNull);

            _serve(url, [_thing('old')]);
            final first = await service.getPosts(feed);
            expect(service.peekPosts(feed), same(first.posts));

            _serve(url, [_thing('new')]);
            expect(_ids((await service.getPosts(feed)).posts), ['new']);
            expect(_requested, [url, url]);
            expect(_ids(service.peekPosts(feed)!), ['new']);
          }));

  test('a failed profile fetch falls back to the one last read',
      () => _online(() async {
            await service.getUserInfo('spez');
            _offline = true;
            expect((await service.getUserInfo('spez')).linkKarma, 183996);
            expect((await service.getUserInfo('nobody')).linkKarma, 0);
          }));

  group('post feed request URIs', () {
    test('frontpage, with after and top time', () => _online(() async {
          _serve('https://old.reddit.com/rising/', [_thing('a')]);
          final page =
              await service.getPosts(const FrontpageFeed(), sort: 'rising');
          expect(_ids(page.posts), ['a']);
          expect(page.next, {'': 't3_a'});

          await expectLater(
            service.getPosts(
              const FrontpageFeed(),
              sort: 'top',
              topTime: 'week',
              after: {'': 't3_x'},
            ),
            throwsA(isA<RedditServiceException>()),
          );
          expect(_requested.last, 'https://old.reddit.com/top/?after=t3_x&t=week');
        }));

    test('one subreddit and a multireddit', () => _online(() async {
          _serve('https://old.reddit.com/r/all/new/', [_thing('a')]);
          _serve('https://old.reddit.com/r/a+b/controversial/', [_thing('b')]);
          expect(
            _ids((await service.getPosts(const SubredditsFeed(['all']),
                    sort: 'new'))
                .posts),
            ['a'],
          );
          expect(
            _ids((await service.getPosts(const SubredditsFeed(['a', 'b']),
                    sort: 'controversial'))
                .posts),
            ['b'],
          );
        }));

    test('a multireddit of no subreddits lists nothing', () => _online(() async {
          expect(service.peekPosts(const SubredditsFeed([])), isNull);
          final page = await service.getPosts(const SubredditsFeed([]));
          expect(page.posts, isEmpty);
          expect(page.next, isNull);
          expect(_requested, isEmpty);
        }));

    test('user submissions carry no sort', () => _online(() async {
          const base = 'https://old.reddit.com/user/someone/submitted/';
          _serve(base, [_thing('a')]);
          _serve('$base?after=t3_a', [_thing('b')]);
          const feed = UserFeed('someone');
          final first = await service.getPosts(feed);
          expect(_ids(first.posts), ['a']);
          expect(
            _ids((await service.getPosts(feed, after: first.next)).posts),
            ['b'],
          );
        }));

    test('following merges user streams, newest first under new',
        () => _online(() async {
              _serve('https://old.reddit.com/user/u1/submitted/?sort=new',
                  [_thing('older', year: 2020)]);
              _serve('https://old.reddit.com/user/u2/submitted/?sort=new',
                  [_thing('newer', year: 2021)]);
              const feed = FollowingFeed(['u1', 'u2']);
              final page = await service.getPosts(feed, sort: 'new');
              expect(_ids(page.posts), ['newer', 'older']);
              expect(page.next, {'u1': 't3_older', 'u2': 't3_newer'});
              expect(_ids(service.peekPosts(feed, sort: 'new')!),
                  ['newer', 'older']);
            }));

    test('following under top merges by score and sends t',
        () => _online(() async {
              _serve('https://old.reddit.com/user/u3/submitted/?sort=top&t=day',
                  [_thing('low', score: 1)]);
              _serve('https://old.reddit.com/user/u4/submitted/?sort=top&t=day',
                  [_thing('high', score: 9)]);
              final page = await service.getPosts(
                const FollowingFeed(['u3', 'u4']),
                sort: 'top',
                topTime: 'day',
              );
              expect(_ids(page.posts), ['high', 'low']);
            }));

    test('following nobody lists nothing', () => _online(() async {
          expect(service.peekPosts(const FollowingFeed([])), isNull);
          expect((await service.getPosts(const FollowingFeed([]))).posts, isEmpty);
        }));

    test('following continues each user from their own last post, until they run out',
        () => _online(() async {
              const u5 = 'https://old.reddit.com/user/u5/submitted/?sort=new';
              const u6 = 'https://old.reddit.com/user/u6/submitted/?sort=new';
              _serve(u5, [_thing('a', year: 2022)]);
              _serve(u6, [_thing('b', year: 2021)]);
              _serve(u5.replaceFirst('?', '?after=t3_a&'), [_thing('c')]);
              _serve(u6.replaceFirst('?', '?after=t3_b&'), []);
              const feed = FollowingFeed(['u5', 'u6']);

              final first = await service.getPosts(feed, sort: 'new');
              expect(first.next, {'u5': 't3_a', 'u6': 't3_b'});

              final second =
                  await service.getPosts(feed, sort: 'new', after: first.next);
              expect(_ids(second.posts), ['c']);
              expect(second.next, {'u5': 't3_c'});

              _requested.clear();
              await expectLater(
                service.getPosts(feed, sort: 'new', after: second.next),
                throwsA(isA<RedditServiceException>()),
              );
              expect(_requested, [u5.replaceFirst('?', '?after=t3_c&')]);
            }));

    test('one unreachable user does not empty the feed; all unreachable is a failure',
        () => _online(() async {
              _serve('https://old.reddit.com/user/u7/submitted/?sort=hot',
                  [_thing('a')]);
              final page =
                  await service.getPosts(const FollowingFeed(['u7', 'gone']));
              expect(_ids(page.posts), ['a']);
              expect(page.next, {'u7': 't3_a'});

              await expectLater(
                service.getPosts(const FollowingFeed(['gone', 'gone2'])),
                throwsA(isA<RedditServiceException>()),
              );
            }));
  });
}
