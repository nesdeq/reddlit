import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/models/reddit_comment.dart';
import 'package:reddlit/models/reddit_user.dart';
import 'package:reddlit/models/subreddit.dart';
import 'package:reddlit/utils/html_to_markdown.dart';

Document _doc(String name) =>
    html_parser.parse(File('test/fixtures/$name').readAsStringSync());

/// Mirrors RedditService._parsePosts: the `#siteTable` link things, minus ads.
List<RedditPost> _posts(Document doc) => doc
    .getElementById('siteTable')!
    .children
    .where((e) => e.classes.contains('thing'))
    .where((e) => (e.attributes['data-fullname'] ?? '').startsWith('t3_'))
    .where((e) => e.attributes['data-promoted'] != 'true')
    .map(RedditPost.fromThing)
    .toList();

List<RedditComment> _flatten(List<RedditComment> comments) => [
      for (final c in comments) ...[c, ..._flatten(c.replies)],
    ];

void main() {
  group('fixture listing-posts.html', () {
    final posts = _posts(_doc('listing-posts.html'));

    test('parses all three link things', () => expect(posts, hasLength(3)));

    test('self-text post classifies as text', () {
      final p = posts[0];
      expect(p.contentType, PostContentType.text);
      expect(p.domain, 'self.Finanzen');
      expect(p.score, 882);
      expect(p.numComments, 371);
    });

    test('i.redd.it post keeps its full-res image url', () {
      final p = posts[1];
      expect(p.contentType, PostContentType.image);
      expect(p.imageUrl, 'https://i.redd.it/agi1jkgz2cch1.jpeg');
    });

    test('v.redd.it listing post: hls manifest is built from the id', () {
      final p = posts[2];
      expect(p.contentType, PostContentType.redditVideo);
      expect(p.videoUrl, 'https://v.redd.it/a1q88btcpcch1/HLSPlaylist.m3u8');
    });
  });

  group('fixture post-detail.html', () {
    final posts = _posts(_doc('post-detail.html'));

    test('self-text post carries its expando body', () {
      final p = posts.firstWhere((p) => p.id == '1us9n0o');
      expect(p.contentType, PostContentType.text);
      expect(p.selftext, contains('beloved cat'));
      expect(p.score, 1632);
      expect(p.numComments, 214);
    });

    test('gallery post exposes rebuilt image urls', () {
      final p = posts.firstWhere((p) => p.id == '1usgznm');
      expect(p.isGallery, isTrue);
      expect(p.contentType, PostContentType.gallery);
      expect(p.galleryImages, isNotEmpty);
      expect(p.galleryImages.every((u) => u.contains('redd.it')), isTrue);
    });
  });

  group('fixture user-profile.html', () {
    final doc = _doc('user-profile.html');

    test('sidebar splits post/comment karma and reads cake day', () {
      final u = RedditUser.fromUserPage(doc, 'spez');
      expect(u.linkKarma, 183996);
      expect(u.commentKarma, 756201);
      expect(u.totalKarma, 940197);
      expect(u.created.year, 2005);
    });

    test('submitted listing parses the user post', () {
      final posts = _posts(doc);
      expect(posts, hasLength(1));
      expect(posts.first.author, 'spez');
      expect(posts.first.score, 798);
      expect(posts.first.numComments, 261);
    });
  });

  group('fixture comments.html', () {
    final table =
        _doc('comments.html').querySelector('.commentarea .sitetable')!;
    final roots = RedditComment.parseThings(
        table, 0, '/r/AskReddit/comments/1us7xml/x/', 't3_1us7xml');
    final all = _flatten(roots);

    test('top comment: author, score, body', () {
      final top = roots.first;
      expect(top.author, 'Pixiegrowler');
      expect(top.score, 1844);
      expect(top.body, contains('Fiskars'));
      expect(top.isMorePlaceholder, isFalse);
    });

    test('a nested reply is reachable with its own score', () {
      final bexlyp = all.firstWhere((c) => c.author == 'Bexlyp');
      expect(bexlyp.score, 154);
    });

    test('load-more placeholders carry the real reply count and a permalink', () {
      final placeholders = all.where((c) => c.isMorePlaceholder).toList();
      expect(placeholders, isNotEmpty);
      expect(placeholders.map((p) => p.replyCount), contains(37));
      expect(placeholders.every((p) => p.morePermalink != null), isTrue);
    });
  });

  group('fixture sorts-pagination.html', () {
    final doc = _doc('sorts-pagination.html');

    test('external-link post reads data-score even when the score is hidden', () {
      final posts = _posts(doc);
      expect(posts, hasLength(2));
      expect(posts[0].contentType, PostContentType.externalLink);
      expect(posts[0].domain, 'zeit.de');
      expect(posts[0].score, 459);
      expect(posts[0].numComments, 353);
    });

    test('stickied score-hidden comment resolves to score 0', () {
      final table = doc.querySelector('.commentarea .sitetable')!;
      final cs = RedditComment.parseThings(
          table, 0, '/r/de/comments/1usin2h/x/', 't3_1usin2h');
      expect(cs.first.author, 'ClausKlebot');
      expect(cs.first.score, 0);
    });
  });

  group('fixture html-to-markdown.html', () {
    final doc = _doc('html-to-markdown.html');
    final mds = doc.querySelectorAll('.md');
    String md(int i) => HtmlToMarkdown.convert(mds[i]);

    test('comment: giphy <a><img> embed renders as one gif image', () {
      final c = RedditComment.fromThing(doc.querySelector('div.thing.comment')!);
      expect(c.author, 'Effective-Pilot9800');
      expect(c.score, 1655);
      expect(c.body,
          contains('![](https://i.giphy.com/media/JWH857oECO0rC/giphy.gif)'));
    });

    test('comment: morechildren + "continue this thread" placeholders', () {
      final c = RedditComment.fromThing(doc.querySelector('div.thing.comment')!);
      final more = _flatten([c]).where((x) => x.isMorePlaceholder).toList();
      expect(more.map((m) => m.replyCount), contains(6));
      final cont = more.firstWhere((m) => m.morePermalink!.contains('owhyci7'));
      expect(
          cont.morePermalink,
          'https://old.reddit.com/r/mildlyinteresting/comments/1urgwis/'
          'amongst_other_things_this_charity_shop_is_not/owhyci7/');
    });

    test('headings, hr, ordered list with bold-in-link', () {
      final out = md(1);
      expect(out, contains('# Welcome to LearnProgramming!'));
      expect(out, contains('---'));
      expect(out, contains('## [**New? READ ME FIRST!**]'));
      expect(out, contains('1. A [**concise but descriptive title**]'));
    });

    test('pre/code fence preserves the entity-decoded query string', () {
      final out = md(2);
      expect(out, contains('```'));
      expect(out,
          contains('bibkeys=ISBN:0201558025,LCCN:93005405&format=json'));
    });

    test('del strike-through and blockquote', () {
      final out = md(3);
      expect(out, startsWith('~~Best Of~~'));
      expect(out, contains('> he yelled'));
    });

    test('nested sup renders stacked carets', () {
      expect(md(4), contains('^^^^AUTOMOD'));
    });

    test('table renders as a markdown grid', () {
      final out = md(5);
      expect(out, contains('| AFC | East |'));
      expect(out, contains('| --- | --- |'));
      expect(out, contains('*NE*'));
    });
  });

  group('fixture community-search.html', () {
    final subs = _doc('community-search.html')
        .querySelectorAll('[data-testid="search-community"]')
        .map(Subreddit.fromCommunityCard)
        .toList()
      ..sort((a, b) => b.weeklyVisitors.compareTo(a.weeklyVisitors));

    test('parses all three community cards', () => expect(subs, hasLength(3)));

    test('top result: name, weekly visitors, real icon, decoded url, blurb', () {
      final cats = subs.first;
      expect(cats.displayName, 'cats');
      expect(cats.weeklyVisitors, 3817748);
      expect(cats.iconUrl, startsWith('https://styles.redditmedia.com/'));
      expect(cats.iconUrl, isNot(contains('&amp;')));
      expect(cats.description, contains('cats'));
    });

    test('ranked by weekly visitors, highest first', () {
      expect(
          subs.map((s) => s.weeklyVisitors).toList(), [3817748, 84522, 23223]);
    });
  });
}
