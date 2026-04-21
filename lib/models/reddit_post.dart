import '../utils/html_utils.dart';
import '../utils/url_utils.dart';
import '../utils/format_utils.dart';

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
  final Map<String, dynamic>? _rawData;

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
    Map<String, dynamic>? rawData,
  }) : _rawData = rawData;

  factory RedditPost.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RedditPost(
      id: data['id'] ?? '',
      title: HtmlUtils.decodeHtmlEntities(data['title'] ?? ''),
      author: data['author'] ?? '[deleted]',
      subreddit: data['subreddit'] ?? '',
      score: data['score'] ?? 0,
      numComments: data['num_comments'] ?? 0,
      created: FormatUtils.fromRedditUtc(data['created_utc']),
      thumbnail: _extractThumbnail(data),
      url: data['url'] as String?,
      selftext: _extractSelftext(data),
      isVideo: data['is_video'] ?? false,
      isGallery: data['is_gallery'] == true,
      domain: data['domain'] ?? '',
      videoUrl: _extractVideoUrl(data),
      rawData: data,
    );
  }

  /// YouTube ID is only needed when the post is rendered — compute lazily to
  /// skip the regex for posts the user scrolls past without viewing.
  late final String? youtubeId = url == null
      ? null
      : UrlUtils.extractYoutubeId(url!);

  /// Gallery images are only needed for gallery posts — compute lazily so
  /// non-gallery posts skip the extraction entirely.
  late final List<String> galleryImages = isGallery && _rawData != null
      ? _extractGalleryImages(_rawData)
      : const [];

  static String? _extractThumbnail(Map<String, dynamic> data) {
    final thumbnail = data['thumbnail'];
    if (thumbnail != null &&
        thumbnail != 'self' &&
        thumbnail != 'default' &&
        thumbnail != 'nsfw' &&
        thumbnail is String &&
        thumbnail.startsWith('http')) {
      return thumbnail;
    }

    try {
      final preview = data['preview'];
      if (preview?['images'] == null || preview['images'].isEmpty) return null;
      final image = preview['images'][0];

      if (image['source']?['url'] != null) {
        return HtmlUtils.decodeHtmlEntities(image['source']['url']);
      }
      if (image['resolutions'] != null && image['resolutions'].isNotEmpty) {
        final resolutions = image['resolutions'] as List;
        final resolution = resolutions.length > 2
            ? resolutions[2]
            : resolutions.last;
        if (resolution['url'] != null) {
          return HtmlUtils.decodeHtmlEntities(resolution['url']);
        }
      }
    } catch (_) {
      // Ignore preview parsing errors
    }
    return null;
  }

  static String? _extractVideoUrl(Map<String, dynamic> data) {
    if (data['is_video'] != true) return null;
    final redditVideo = data['media']?['reddit_video'];
    if (redditVideo == null) return null;
    // Prefer HLS (includes audio), fallback to DASH.
    return redditVideo['hls_url'] as String? ??
        redditVideo['fallback_url'] as String?;
  }

  static String? _extractSelftext(Map<String, dynamic> data) {
    final selftext = data['selftext'];
    if (selftext == null || (selftext as String).isEmpty) return null;
    return HtmlUtils.decodeHtmlEntities(selftext);
  }

  static List<String> _extractGalleryImages(Map<String, dynamic> data) {
    try {
      final galleryData = data['gallery_data'];
      final mediaMetadata = data['media_metadata'] as Map<String, dynamic>?;
      if (galleryData?['items'] == null || mediaMetadata == null) return [];

      final images = <String>[];
      for (final item in galleryData['items']) {
        final mediaId = item['media_id'];
        final media = mediaMetadata[mediaId];
        if (media?['s']?['u'] != null) {
          images.add(HtmlUtils.decodeHtmlEntities(media['s']['u']));
        }
      }
      return images;
    } catch (_) {
      return [];
    }
  }

  String get imageUrl {
    if (url != null && url!.isNotEmpty) return url!;
    return thumbnail ?? '';
  }

  PostContentType get contentType {
    if (isGallery && galleryImages.isNotEmpty) return PostContentType.gallery;
    if (url == null || domain.contains('reddit.com')) {
      return PostContentType.text;
    }
    // Check isVideo flag BEFORE youtube/image — prevents misclassification.
    if (isVideo) return PostContentType.redditVideo;
    if (youtubeId != null) return PostContentType.youtubeVideo;
    if (UrlUtils.isImageUrl(url!)) return PostContentType.image;
    if (UrlUtils.isVideoUrl(url!)) return PostContentType.video;
    return PostContentType.externalLink;
  }
}
