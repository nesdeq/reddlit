import 'package:html/dom.dart';
import '../utils/url_utils.dart';
import '../utils/format_utils.dart';
import '../utils/html_to_markdown.dart';

enum PostContentType {
  text,
  image,
  gallery,
  video,
  externalLink,
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
    this.selftext,
    required this.isVideo,
    this.isGallery = false,
    required this.domain,
    this.videoUrl,
    this.galleryImages = const [],
  });

  /// Parse a post from an old.reddit `div.thing` element.
  ///
  /// The listing thing is lean (metadata + thumbnail + video manifests). The
  /// same thing on a post page additionally carries the selftext body and
  /// gallery image set in its expando — [fromThing] extracts whatever is
  /// present, so one parser serves both feed and detail.
  factory RedditPost.fromThing(Element thing) {
    String? attr(String name) => thing.attributes['data-$name'];

    final fullname = attr('fullname') ?? '';
    final id = fullname.startsWith('t3_') ? fullname.substring(3) : fullname;

    final hls = _clean(attr('hls-url'));
    final mpd = _clean(attr('mpd-url'));
    final dataUrl = _clean(attr('url'));
    final domain = attr('domain') ?? '';
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
      selftext: _extractSelftext(thing),
      isVideo: isVideo,
      isGallery: attr('is-gallery') == 'true',
      domain: domain,
      videoUrl: hls ?? mpd,
      galleryImages: _extractGalleryImages(thing),
    );
  }

  /// YouTube ID is only needed when the post is rendered — compute lazily to
  /// skip the regex for posts the user scrolls past without viewing.
  late final String? youtubeId = url == null
      ? null
      : UrlUtils.extractYoutubeId(url!);

  /// old.reddit emits protocol-relative URLs (`//preview.redd.it/…`); normalize
  /// to https and decode entity-escaped query separators.
  static String? _clean(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var url = raw.replaceAll('&amp;', '&');
    if (url.startsWith('//')) url = 'https:$url';
    return url;
  }

  static String? _extractThumbnail(Element thing) {
    final src = thing.querySelector('a.thumbnail img')?.attributes['src'];
    return _clean(src);
  }

  /// Selftext lives in the post's own expando, present only on the post page.
  /// Scoped to the entry so it can't pick up a comment body.
  static String? _extractSelftext(Element thing) {
    final md = thing.querySelector('.entry .usertext-body .md');
    if (md == null) return null;
    final markdown = HtmlToMarkdown.convert(md);
    return markdown.isEmpty ? null : markdown;
  }

  /// Gallery image URLs are rendered into the post page expando. Collect the
  /// distinct reddit-hosted image URLs in document order.
  static List<String> _extractGalleryImages(Element thing) {
    if (thing.attributes['data-is-gallery'] != 'true') return const [];
    final seen = <String>{};
    final images = <String>[];
    void consider(String? raw) {
      final url = _clean(raw);
      if (url == null) return;
      if (!_galleryImagePattern.hasMatch(url)) return;
      final key = url.split('?').first;
      if (seen.add(key)) images.add(url);
    }

    for (final a in thing.querySelectorAll('.entry a[href]')) {
      consider(a.attributes['href']);
    }
    for (final img in thing.querySelectorAll('.entry img[src]')) {
      consider(img.attributes['src']);
    }
    return images;
  }

  static final _galleryImagePattern = RegExp(
    r'https?://(?:i|preview)\.redd\.it/[A-Za-z0-9._-]+\.(?:jpg|jpeg|png|webp|gif)',
    caseSensitive: false,
  );

  String get imageUrl {
    // For galleries with no loaded images (feed), fall back to the cover thumb.
    if (isGallery && galleryImages.isEmpty) return thumbnail ?? '';
    if (url != null && url!.isNotEmpty) return url!;
    return thumbnail ?? '';
  }

  PostContentType get contentType {
    if (isGallery && galleryImages.isNotEmpty) return PostContentType.gallery;
    // Check isVideo flag BEFORE youtube/image — prevents misclassification.
    if (isVideo) return PostContentType.redditVideo;
    if (youtubeId != null) return PostContentType.youtubeVideo;
    // Gallery cover in the feed (no images loaded yet) renders as an image.
    if (isGallery && (thumbnail?.isNotEmpty ?? false)) {
      return PostContentType.image;
    }
    if (url == null || domain.contains('reddit.com')) {
      return PostContentType.text;
    }
    if (UrlUtils.isImageUrl(url!)) return PostContentType.image;
    if (UrlUtils.isVideoUrl(url!)) return PostContentType.video;
    return PostContentType.externalLink;
  }
}
