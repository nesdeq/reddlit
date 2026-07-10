import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/models/reddit_comment.dart';
import 'package:reddlit/models/reddit_user.dart';
import 'package:reddlit/models/subreddit.dart';
import 'package:reddlit/utils/html_to_markdown.dart';
import 'package:reddlit/utils/url_utils.dart';

Element _thing(String html) => html_parser.parse(html).querySelector('.thing')!;
Element _md(String html) =>
    html_parser.parse('<div class="md">$html</div>').querySelector('.md')!;
String _toMd(String inner) => HtmlToMarkdown.convert(_md(inner));

void main() {
  group('RedditPost.contentType', () {
    test('self-text post (data-domain="self.X") is text, not a link card', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_s" data-domain="self.AskReddit" '
          'data-url="/r/AskReddit/comments/s/title/" data-author="u" '
          'data-subreddit="AskReddit" data-score="1" data-comments-count="1" '
          'data-timestamp="1700000000000"><a class="title">Q?</a></div>');
      expect(RedditPost.fromThing(t).contentType, PostContentType.text);
    });

    test('v.redd.it video: hls comes from a descendant [data-hls-url] node', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_v" data-domain="v.redd.it" '
          'data-url="https://v.redd.it/abc" data-author="u" data-subreddit="s" '
          'data-score="1" data-comments-count="1" data-timestamp="1700000000000">'
          '<a class="title">V</a><div class="entry"><div class="expando">'
          '<div id="video-v" data-hls-url="https://v.redd.it/abc/HLSPlaylist.m3u8?a=1" '
          'data-mpd-url="https://v.redd.it/abc/DASHPlaylist.mpd"></div>'
          '</div></div></div>');
      final p = RedditPost.fromThing(t);
      expect(p.contentType, PostContentType.redditVideo);
      expect(p.videoUrl, 'https://v.redd.it/abc/HLSPlaylist.m3u8?a=1');
    });

    test('v.redd.it listing post: hls is constructed from the id', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_v" data-domain="v.redd.it" '
          'data-url="https://v.redd.it/abc123" data-author="u" data-subreddit="s" '
          'data-score="1" data-comments-count="1" data-timestamp="1700000000000">'
          '<a class="title">V</a></div>');
      final p = RedditPost.fromThing(t);
      expect(p.contentType, PostContentType.redditVideo);
      expect(p.videoUrl, 'https://v.redd.it/abc123/HLSPlaylist.m3u8');
    });

    test('gallery cover is rebuilt full-res from the thumbnail hash', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_g" data-is-gallery="true" '
          'data-domain="old.reddit.com" data-url="https://www.reddit.com/gallery/g" '
          'data-author="u" data-subreddit="pics" data-score="1" '
          'data-comments-count="1" data-timestamp="1700000000000">'
          '<a class="title">G</a>'
          '<a class="thumbnail"><img src="//preview.redd.it/deadbeef01.jpg?width=140&amp;s=x"></a>'
          '</div>');
      final p = RedditPost.fromThing(t);
      expect(p.contentType, PostContentType.image);
      expect(p.imageUrl, 'https://i.redd.it/deadbeef01.jpg');
    });

    test('single i.redd.it image keeps its full-res url', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_i" data-domain="i.redd.it" '
          'data-url="https://i.redd.it/pic1.jpeg" data-author="u" '
          'data-subreddit="pics" data-score="1" data-comments-count="1" '
          'data-timestamp="1700000000000"><a class="title">I</a></div>');
      final p = RedditPost.fromThing(t);
      expect(p.contentType, PostContentType.image);
      expect(p.imageUrl, 'https://i.redd.it/pic1.jpeg');
    });
  });

  group('RedditComment placeholders', () {
    RedditComment onlyPlaceholder(String innerThing) {
      final table =
          html_parser.parse('<div class="sitetable">$innerThing</div>')
              .querySelector('.sitetable')!;
      final out =
          RedditComment.parseThings(table, 0, '/r/x/comments/y/', 't3_y');
      expect(out.length, 1);
      return out.first;
    }

    test('"continue this thread" (morerecursion + .deepthread) is parsed', () {
      final c = onlyPlaceholder(
          '<div class="thing morerecursion" data-fullname="t1__"><span class="deepthread">'
          '<a href="/r/x/comments/y/z/abc/">continue this thread</a></span></div>');
      expect(c.isMorePlaceholder, isTrue);
      expect(c.morePermalink, 'https://old.reddit.com/r/x/comments/y/z/abc/');
    });

    test('"load more" shows the real reply count, not the fetch-batch size', () {
      final c = onlyPlaceholder(
          '<div class="thing morechildren"><span class="morecomments">'
          "<a href=\"#\" onclick=\"morechildren(this,'t3_y','confidence','c1:t1_a,t1_b','False')\">"
          'load more comments <span class="gray">(1500 replies)</span></a></span></div>');
      expect(c.isMorePlaceholder, isTrue);
      expect(c.moreChildrenIds.length, 2);
      expect(c.replyCount, 1500);
    });
  });

  group('HtmlToMarkdown', () {
    test('pasted image link renders inline, not as a link', () {
      expect(_toMd('<p><a href="https://i.redd.it/x.png">look</a></p>'),
          '![look](https://i.redd.it/x.png)');
    });

    test('giphy <a><img> embed becomes one clean gif image', () {
      expect(
          _toMd('<p><a href="https://giphy.com/gifs/JWH857oECO0rC">'
              '<img src="https://external-preview.redd.it/x.gif?width=492&amp;s=abc"></a></p>'),
          '![](https://i.giphy.com/media/JWH857oECO0rC/giphy.gif)');
    });

    test('giphy page url with title slug resolves to the id', () {
      expect(
          _toMd('<p><a href="https://giphy.com/gifs/gross-ew-nasty-k2A4gzRxDL4GI">x</a></p>'),
          '![x](https://i.giphy.com/media/k2A4gzRxDL4GI/giphy.gif)');
    });

    test('protocol-relative img src is upgraded to https', () {
      expect(_toMd('<p><img src="//preview.redd.it/y.jpg?width=1&amp;s=2" alt=""></p>'),
          '![](https://preview.redd.it/y.jpg?width=1&s=2)');
    });

    test('non-image link stays a link', () {
      expect(_toMd('<p><a href="https://example.com/article">read</a></p>'),
          '[read](https://example.com/article)');
    });

    test('inter-paragraph whitespace does not create spurious blocks', () {
      expect(_toMd('<p>a</p>\n\n<p>b</p>'), 'a\n\nb');
    });
  });

  group('UrlUtils.isImageUrl', () {
    test('imgur album page is NOT a direct image', () {
      expect(UrlUtils.isImageUrl('https://imgur.com/a/e28AUTj'), isFalse);
    });
    test('i.imgur.com raw image IS an image', () {
      expect(UrlUtils.isImageUrl('https://i.imgur.com/abc.png'), isTrue);
    });
    test('i.redd.it image is an image', () {
      expect(UrlUtils.isImageUrl('https://i.redd.it/x.jpg'), isTrue);
    });
    test('host-spoof imgur.com.evil.tld is not an image', () {
      expect(UrlUtils.isImageUrl('https://i.imgur.com.evil.tld/x'), isFalse);
    });
  });

  group('RedditUser.fromUserPage', () {
    test('distinguishes link vs comment karma and reads cake day', () {
      final doc = html_parser.parse(
          '<html><body><div class="side"><div class="titlebox">'
          '<span class="karma">1,234</span>'
          '<span class="karma comment-karma">5,678</span>'
          '<span class="age"><time datetime="2015-06-01T00:00:00+00:00">x</time></span>'
          '</div></div></body></html>');
      final u = RedditUser.fromUserPage(doc, 'spez');
      expect(u.linkKarma, 1234);
      expect(u.commentKarma, 5678);
      expect(u.created.year, 2015);
    });
  });

  group('Subreddit.fromThing', () {
    test('reads name and community age (no subscriber count in search)', () {
      final t = _thing(
          '<div class="thing subreddit" data-fullname="t5_x">'
          '<p class="titlerow"><a class="title" href="https://old.reddit.com/r/Flutter/">'
          'r/Flutter: Flutter</a></p>'
          '<p class="tagline">a community for 12 years</p></div>');
      final s = Subreddit.fromThing(t);
      expect(s.displayName, 'Flutter');
      expect(s.age, '12 years');
    });
  });
}
