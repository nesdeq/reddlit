import 'package:html/dom.dart';
import '../utils/reddit_link.dart';
import '../utils/url_utils.dart';
import '../utils/format_utils.dart';
import '../utils/html_to_markdown.dart';

enum PostContentType {
  text,
  image,
  gallery,
  video,
  externalLink,
  redditLink,
  redditVideo,
  youtubeVideo,
}

class RedditPost {
  final String id;
  final String title;
  final String author;
  final String subreddit;
  final int score;
  final int numComments;
  final DateTime created;
  final String? thumbnail;
  final String? url;
  final String? permalink;
  final String? selftext;
  final bool isVideo;
  final bool isGallery;
  final String domain;
  final String? videoUrl;
  final List<String> galleryImages;

  RedditPost({
    required this.id,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.score,
    required this.numComments,
    required this.created,
    this.thumbnail,
    this.url,
    this.permalink,
    this.selftext,
    required this.isVideo,
    this.isGallery = false,
    required this.domain,
    this.videoUrl,
    this.galleryImages = const [],
  });

  /// Parse an old.reddit `div.thing`; only the post-page thing carries selftext.
  factory RedditPost.fromThing(Element thing) {
    String? attr(String name) => thing.attributes['data-$name'];

    final fullname = attr('fullname') ?? '';
    final id = fullname.startsWith('t3_') ? fullname.substring(3) : fullname;

    final dataUrl = UrlUtils.fromAttribute(attr('url'));
    final domain = attr('domain') ?? '';
    final hls = UrlUtils.fromAttribute(
            thing.querySelector('[data-hls-url]')?.attributes['data-hls-url']) ??
        _redditVideoHls(domain, dataUrl);
    final mpd = UrlUtils.fromAttribute(
        thing.querySelector('[data-mpd-url]')?.attributes['data-mpd-url']);
    final isVideo = hls != null || mpd != null || domain == 'v.redd.it';

    return RedditPost(
      id: id,
      title: thing.querySelector('a.title')?.text.trim() ?? '',
      author: attr('author') ?? '[deleted]',
      subreddit: attr('subreddit') ?? '',
      score: int.tryParse(attr('score') ?? '') ?? 0,
      numComments: int.tryParse(attr('comments-count') ?? '') ?? 0,
      created: FormatUtils.fromRedditMillis(attr('timestamp')),
      thumbnail: _extractThumbnail(thing),
      url: dataUrl,
      permalink: attr('permalink'),
      selftext: _extractSelftext(thing),
      isVideo: isVideo,
      isGallery: attr('is-gallery') == 'true',
      domain: domain,
      videoUrl: hls ?? mpd,
      galleryImages: _extractGalleryImages(thing),
    );
  }

  /// Posts of a listing page's `#siteTable`, minus promoted ads and non-link things.
  static List<RedditPost> parseListing(Document doc) {
    final table = doc.getElementById('siteTable');
    if (table == null) return const [];
    return table.children
        .where((e) => e.classes.contains('thing'))
        .where((e) => (e.attributes['data-fullname'] ?? '').startsWith('t3_'))
        .where((e) => e.attributes['data-promoted'] != 'true')
        .map(RedditPost.fromThing)
        .toList();
  }

  /// Computed lazily: posts scrolled past never run the regex.
  late final String? youtubeId = url == null
      ? null
      : UrlUtils.extractYoutubeId(url!);

  /// The other thread, subreddit or user this post links to; null when the URL is the post itself.
  late final RedditLink? redditLink = _citedLink();

  RedditLink? _citedLink() {
    final link = url == null ? null : RedditLink.parse(url!);
    return link is ThreadLink && link.postId == id ? null : link;
  }

  static String? _redditVideoHls(String domain, String? url) {
    if (domain != 'v.redd.it' || url == null) return null;
    final id = RegExp(r'v\.redd\.it/([A-Za-z0-9]+)').firstMatch(url)?.group(1);
    return id == null ? null : 'https://v.redd.it/$id/HLSPlaylist.m3u8';
  }

  static String? _extractThumbnail(Element thing) {
    final src = thing.querySelector('a.thumbnail img')?.attributes['src'];
    return UrlUtils.fromAttribute(src);
  }

  /// Selftext lives in the post's own expando, present only on the post page.
  /// Scoped to the entry so it can't pick up a comment body.
  static String? _extractSelftext(Element thing) {
    final md = thing.querySelector('.entry .usertext-body .md');
    if (md == null) return null;
    final markdown = HtmlToMarkdown.convert(md);
    return markdown.isEmpty ? null : markdown;
  }

  /// The post's media markup: rendered into the expando where reddit auto-expands previews, escaped in its `data-cachedhtml` elsewhere.
  static Element? _media(Element thing) {
    final expando = thing.querySelector('.entry .expando');
    final cached = expando?.attributes['data-cachedhtml'];
    return cached == null ? expando : (Element.tag('div')..innerHtml = cached);
  }

  /// A gallery's distinct reddit-hosted image URLs in document order, full-size links before previews.
  static List<String> _extractGalleryImages(Element thing) {
    if (thing.attributes['data-is-gallery'] != 'true') return const [];
    final media = _media(thing);
    if (media == null) return const [];
    final seen = <String>{};
    final images = <String>[];
    void consider(String? raw) {
      final url = UrlUtils.fromAttribute(raw);
      if (url == null) return;
      if (!_galleryImagePattern.hasMatch(url)) return;
      final key = url.split('?').first;
      if (seen.add(key)) images.add(url);
    }

    for (final a in media.querySelectorAll('a[href]')) {
      consider(a.attributes['href']);
    }
    for (final img in media.querySelectorAll('img[src]')) {
      consider(img.attributes['src']);
    }
    return images;
  }

  static final _galleryImagePattern = RegExp(
    r'https?://(?:i|preview)\.redd\.it/[A-Za-z0-9._-]+\.(?:jpg|jpeg|png|webp|gif)',
    caseSensitive: false,
  );

  /// A feed card's picture for a gallery: its first image, or the one its thumbnail was cut from while the images are unknown.
  late final String? galleryCover =
      galleryImages.firstOrNull ?? _coverFromThumbnail(thumbnail) ?? thumbnail;

  static String? _coverFromThumbnail(String? thumb) {
    if (thumb == null) return null;
    final m = RegExp(
      r'/preview\.redd\.it/([A-Za-z0-9]+)\.(jpg|jpeg|png|webp|gif)',
      caseSensitive: false,
    ).firstMatch(thumb);
    if (m == null) return null;
    return 'https://i.redd.it/${m.group(1)}.${m.group(2)}';
  }

  PostContentType get contentType {
    if (isGallery && galleryImages.isNotEmpty) return PostContentType.gallery;
    // isVideo is checked before youtube and image so a video post is never misclassified.
    if (isVideo) return PostContentType.redditVideo;
    if (youtubeId != null) return PostContentType.youtubeVideo;
    // A gallery whose images are unknown still has a cover for the feed.
    if (isGallery && (thumbnail?.isNotEmpty ?? false)) {
      return PostContentType.gallery;
    }
    if (url == null || isGallery) return PostContentType.text;
    if (redditLink != null) return PostContentType.redditLink;
    if (domain.startsWith('self.')) return PostContentType.text;
    if (UrlUtils.isImageUrl(url!)) return PostContentType.image;
    if (UrlUtils.isVideoUrl(url!)) return PostContentType.video;
    return PostContentType.externalLink;
  }
}
