import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/models/reddit_comment.dart';
import 'package:reddlit/models/reddit_user.dart';
import 'package:reddlit/models/subreddit.dart';
import 'package:reddlit/services/reddit_service.dart';
import 'package:reddlit/services/request_pipeline.dart';
import 'package:reddlit/utils/html_to_markdown.dart';
import 'package:reddlit/utils/reddit_link.dart';
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

    group('posts that link to reddit itself', () {
      RedditPost post({required String domain, required String url, String gallery = ''}) =>
          RedditPost.fromThing(_thing(
              '<div class="thing" data-fullname="t3_self" data-domain="$domain" '
              'data-url="$url" $gallery data-author="u" data-subreddit="bestof" '
              'data-score="1" data-comments-count="1" data-timestamp="1700000000000">'
              '<a class="title">T</a></div>'));

      test('a cited comment thread is a reddit link, not empty text', () {
        for (final (domain, url) in [
          ('reddit.com', 'https://www.reddit.com/r/AskHistorians/comments/abc/t/def/?context=3'),
          ('old.reddit.com', '/r/AskHistorians/comments/abc/t/def/'),
          ('np.reddit.com', 'https://np.reddit.com/r/AskHistorians/comments/abc/t/'),
        ]) {
          final p = post(domain: domain, url: url);
          expect(p.contentType, PostContentType.redditLink, reason: url);
          expect((p.redditLink! as ThreadLink).postId, 'abc');
        }
      });

      test('a crossposted self post links to the original', () {
        final p = post(domain: 'self.other', url: '/r/other/comments/orig/t/');
        expect(p.contentType, PostContentType.redditLink);
      });

      test('a link to a subreddit or user is a reddit link', () {
        expect(post(domain: 'reddit.com', url: 'https://www.reddit.com/r/dartlang/').contentType,
            PostContentType.redditLink);
      });

      test('its own permalink is not a cite', () {
        final p = post(domain: 'self.bestof', url: '/r/bestof/comments/self/t/');
        expect(p.redditLink, isNull);
        expect(p.contentType, PostContentType.text);
      });

      test('a gallery without a cover stays text', () {
        final p = post(
            domain: 'old.reddit.com',
            url: 'https://www.reddit.com/gallery/other',
            gallery: 'data-is-gallery="true"');
        expect(p.contentType, PostContentType.text);
      });

      test('other reddit pages show as an external link', () {
        expect(post(domain: 'reddit.com', url: 'https://www.reddit.com/wiki/index').contentType,
            PostContentType.externalLink);
      });
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

    test('captures data-permalink; a non-ascii title encodes for the fetch', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_x" data-domain="digitalrechte.de" '
          'data-url="https://digitalrechte.de/x" '
          'data-permalink="/r/de/comments/1ushh0x/bundesregierung_eskaliert_überwachung_jetzt_kommt/" '
          'data-author="u" data-subreddit="de" data-score="1" '
          'data-comments-count="1" data-timestamp="1700000000000">'
          '<a class="title">T</a></div>');
      final p = RedditPost.fromThing(t);
      expect(p.permalink, contains('überwachung'));
      final uri = Uri.https('old.reddit.com', p.permalink!, {'sort': 'confidence'});
      expect(uri.toString(), contains('%C3%BC'));
      expect(uri.toString(), isNot(contains('überwachung')));
    });

    test('an out-of-range data-timestamp does not crash the parse', () {
      final t = _thing(
          '<div class="thing" data-fullname="t3_x" data-domain="self.x" '
          'data-url="/r/x/comments/x/t/" data-author="u" data-subreddit="x" '
          'data-score="1" data-comments-count="1" '
          'data-timestamp="9000000000000000000"><a class="title">T</a></div>');
      expect(() => RedditPost.fromThing(t), returnsNormally);
      expect(RedditPost.fromThing(t).created,
          DateTime.fromMillisecondsSinceEpoch(0));
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

    test('pathologically nested markup degrades, does not overflow the stack', () {
      const depth = 40000;
      // Block recursion. The chain is built directly: package:html parses
      // nested blockquotes quadratically (about 30 s at this depth).
      final root = Element.tag('div');
      var parent = root;
      for (var i = 0; i < depth; i++) {
        final child = Element.tag('blockquote');
        parent.append(child);
        parent = child;
      }
      parent.append(Text('x'));
      expect(() => HtmlToMarkdown.convert(root), returnsNormally);

      // el.text over a deep subtree (the image-link alt).
      final spans = '${'<span>' * depth}x${'</span>' * depth}';
      expect(() => _toMd('<a href="x.jpg">$spans</a>'), returnsNormally);
    });
  });

  group('UrlUtils.fromAttribute', () {
    test('decodes &amp; and upgrades protocol-relative urls', () {
      expect(UrlUtils.fromAttribute('//preview.redd.it/a.jpg?w=1&amp;s=2'),
          'https://preview.redd.it/a.jpg?w=1&s=2');
      expect(UrlUtils.fromAttribute('https://i.redd.it/a.jpg'),
          'https://i.redd.it/a.jpg');
    });
    test('missing or empty is null', () {
      expect(UrlUtils.fromAttribute(null), isNull);
      expect(UrlUtils.fromAttribute(''), isNull);
    });
  });

  group('UrlUtils.canSummarize', () {
    test('an external article can be summarized', () {
      expect(UrlUtils.canSummarize('https://www.zeit.de/politik/x'), isTrue);
    });
    test('a self post, whose url is its own relative permalink, cannot', () {
      expect(UrlUtils.canSummarize('/r/Finanzen/comments/1usera3/title/'),
          isFalse);
      expect(UrlUtils.canSummarize('/user/spez/comments/1u7hraf/title/'),
          isFalse);
    });
    test('reddit pages, media and nothing cannot', () {
      expect(UrlUtils.canSummarize('https://www.reddit.com/r/x/comments/y/'),
          isFalse);
      expect(UrlUtils.canSummarize('https://i.redd.it/x.jpg'), isFalse);
      expect(UrlUtils.canSummarize(null), isFalse);
      expect(UrlUtils.canSummarize(''), isFalse);
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

  group('Subreddit.fromCommunityCard', () {
    test('reads name, weekly visitors, icon, and description', () {
      final doc = html_parser.parse(
          '<div data-testid="search-community">'
          '<a href="/r/Flutter/"></a>'
          '<img src="https://styles.redditmedia.com/t5_x/styles/communityIcon_a.png?width=64&amp;s=1">'
          '<span id="search-community-title-t5_x">r/Flutter</span>'
          '<p data-testid="search-subreddit-desc-text">Flutter news.</p>'
          '<faceplate-number number="123456" pretty></faceplate-number> weekly visitors'
          '</div>');
      final card = doc.querySelector('[data-testid="search-community"]')!;
      final s = Subreddit.fromCommunityCard(card);
      expect(s.displayName, 'Flutter');
      expect(s.weeklyVisitors, 123456);
      expect(s.description, 'Flutter news.');
      expect(s.iconUrl,
          'https://styles.redditmedia.com/t5_x/styles/communityIcon_a.png?width=64&s=1');
    });
  });

  group('RedditService.moreCommentsUri', () {
    test('single-encodes a non-ascii permalink and sets the sort', () {
      final uri = RedditService().moreCommentsUri(
        'https://old.reddit.com/r/de/comments/1ushh0x/x_überwachung_y/',
        'confidence',
      );
      expect(uri.toString(), contains('%C3%BC'));
      expect(uri.toString(), isNot(contains('%25C3'))); // not double-encoded
      expect(uri.queryParameters['sort'], 'confidence');
    });
  });

  group('RequestPipeline.looksBlocked', () {
    test('fires on a bare block / verification interstitial', () {
      expect(
          RequestPipeline.looksBlocked(
              '<html><body>you have been blocked by network security</body></html>'),
          isTrue);
      expect(
          RequestPipeline.looksBlocked(
              '<html><body>Please wait for verification</body></html>'),
          isTrue);
    });

    test('does NOT fire when a trigger phrase is inside real content', () {
      expect(
          RequestPipeline.looksBlocked(
              '<div id="siteTable"><div class="thing" data-fullname="t3_x">'
              '<a class="title">blocked by network security?</a></div></div>'),
          isFalse);
      expect(
          RequestPipeline.looksBlocked(
              '<div class="commentarea"><div class="md">Please try to login worked</div></div>'),
          isFalse);
      expect(
          RequestPipeline.looksBlocked(
              '<div data-testid="search-community"><p>Please wait for verification memes</p></div>'),
          isFalse);
    });

    test('no trigger phrase, no block', () {
      expect(RequestPipeline.looksBlocked('<div id="siteTable">ok</div>'),
          isFalse);
    });
  });
}
