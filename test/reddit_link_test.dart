import 'package:flutter_test/flutter_test.dart';

import 'package:reddlit/utils/reddit_link.dart';

void main() {
  ThreadLink thread(String url) => RedditLink.parse(url)! as ThreadLink;

  group('threads', () {
    test('post permalink on any reddit host', () {
      for (final host in ['www.reddit.com', 'old.reddit.com', 'np.reddit.com', 'reddit.com']) {
        final link = thread('https://$host/r/AskHistorians/comments/abc123/some_title/');
        expect(link.subreddit, 'AskHistorians');
        expect(link.postId, 'abc123');
        expect(link.commentId, isNull);
        expect(link.path, '/r/AskHistorians/comments/abc123/some_title/');
      }
    });

    test('comment permalink keeps the comment and its context', () {
      final link = thread(
          'https://www.reddit.com/r/x/comments/abc/slug/def456/?context=3');
      expect(link.commentId, 'def456');
      expect(link.context, '3');
      expect(link.path, '/r/x/comments/abc/slug/def456/');
    });

    test('relative href, as reddit renders links inside comments', () {
      final link = thread('/r/x/comments/abc/slug/');
      expect((link.subreddit, link.postId), ('x', 'abc'));
    });

    test('a percent-encoded slug decodes once', () {
      expect(thread('https://old.reddit.com/r/de/comments/abc/%C3%BCber/').path,
          '/r/de/comments/abc/über/');
    });

    test('a post on a user profile', () {
      final link = thread('/u/spez/comments/1u7hraf/21_years_of_reddit/');
      expect(link.subreddit, isNull);
      expect(link.postId, '1u7hraf');
      expect(link.path, '/user/spez/comments/1u7hraf/21_years_of_reddit/');
    });

    test('short forms without a subreddit', () {
      expect(thread('https://redd.it/abc123').path, '/comments/abc123/');
      expect(thread('https://www.reddit.com/comments/abc123').postId, 'abc123');
      expect(thread('https://www.reddit.com/gallery/abc123').postId, 'abc123');
    });
  });

  test('a share link keeps the address that reveals its target', () {
    for (final url in [
      'https://www.reddit.com/r/books/s/AbC123xyz',
      'https://reddit.com/r/books/s/AbC123xyz/',
      '/r/books/s/AbC123xyz',
    ]) {
      final link = RedditLink.parse(url)! as ShareLink;
      expect(link.uri.toString(), 'https://www.reddit.com/r/books/s/AbC123xyz',
          reason: url);
    }
    expect(
      (RedditLink.parse('https://www.reddit.com/u/spez/s/AbC123')! as ShareLink)
          .uri
          .path,
      '/u/spez/s/AbC123',
    );
  });

  test('the address a share link redirects to is a thread', () {
    final link = thread('https://www.reddit.com/r/books/comments/abc/slug/def/'
        '?share_id=x&utm_medium=android_app&utm_name=androidcss');
    expect((link.postId, link.commentId), ('abc', 'def'));
    expect(link.path, '/r/books/comments/abc/slug/def/');
  });

  test('subreddits, with or without a sort', () {
    expect((RedditLink.parse('/r/dartlang')! as SubredditLink).name, 'dartlang');
    expect((RedditLink.parse('https://reddit.com/r/dartlang/top/')! as SubredditLink).name,
        'dartlang');
  });

  test('users under /u and /user', () {
    expect((RedditLink.parse('/u/spez')! as UserLink).name, 'spez');
    expect((RedditLink.parse('https://old.reddit.com/user/spez/')! as UserLink).name, 'spez');
  });

  test('everything else is not an in-app destination', () {
    for (final url in [
      'https://example.com/r/x/comments/abc/',
      'https://reddit.com.evil.tld/r/x/comments/abc/',
      'https://i.redd.it/abc.jpg',
      'https://v.redd.it/abc',
      'https://www.reddit.com/wiki/index',
      'https://www.reddit.com/r/x/wiki/rules',
      'https://old.reddit.com/login/',
      'https://www.reddit.com/',
      'mailto:someone@example.com',
      'not a url',
      '',
    ]) {
      expect(RedditLink.parse(url), isNull, reason: url);
    }
  });
}
