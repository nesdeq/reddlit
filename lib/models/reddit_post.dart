import '../utils/html_utils.dart';
import '../utils/url_utils.dart';
import '../utils/format_utils.dart';

enum PostContentType {
  text,
  image,
  gallery, // Multiple images
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
  final String domain;
  final String? videoUrl;
  final String? youtubeId;
  final List<String> galleryImages; // For Reddit gallery posts

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
    required this.domain,
    this.videoUrl,
    this.youtubeId,
    this.galleryImages = const [],
  });

  factory RedditPost.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final url = data['url'] as String?;

    return RedditPost(
      id: data['id'] ?? '',
      title: HtmlUtils.decodeHtmlEntities(data['title'] ?? ''),
      author: data['author'] ?? '[deleted]',
      subreddit: data['subreddit'] ?? '',
      score: data['score'] ?? 0,
      numComments: data['num_comments'] ?? 0,
      created: FormatUtils.fromRedditUtc(data['created_utc']),
      thumbnail: _extractThumbnail(data),
      url: url,
      selftext: _extractSelftext(data),
      isVideo: data['is_video'] ?? false,
      domain: data['domain'] ?? '',
      videoUrl: _extractVideoUrl(data),
      youtubeId: url != null ? UrlUtils.extractYoutubeId(url) : null,
      galleryImages: _extractGalleryImages(data),
    );
  }

  /// Extract best available thumbnail from data
  static String? _extractThumbnail(Map<String, dynamic> data) {
    // Try basic thumbnail first - inline validation
    final thumbnail = data['thumbnail'];
    if (thumbnail != null &&
        thumbnail != 'self' &&
        thumbnail != 'default' &&
        thumbnail != 'nsfw' &&
        thumbnail is String &&
        thumbnail.startsWith('http')) {
      return thumbnail;
    }

    // Try preview images
    try {
      final preview = data['preview'];
      if (preview?['images'] == null || preview['images'].isEmpty) return null;

      final image = preview['images'][0];

      // Try source URL first
      if (image['source']?['url'] != null) {
        return HtmlUtils.decodeHtmlEntities(image['source']['url']);
      }

      // Try resolutions for better quality thumbnails
      if (image['resolutions'] != null && image['resolutions'].isNotEmpty) {
        final resolutions = image['resolutions'] as List;
        final resolution = resolutions.length > 2 ? resolutions[2] : resolutions.last;
        if (resolution['url'] != null) {
          return HtmlUtils.decodeHtmlEntities(resolution['url']);
        }
      }
    } catch (_) {
      // Ignore preview parsing errors
    }

    return null;
  }

  /// Extract video URL from Reddit-hosted videos (prefers HLS with audio)
  static String? _extractVideoUrl(Map<String, dynamic> data) {
    if (data['is_video'] != true) return null;

    final redditVideo = data['media']?['reddit_video'];
    if (redditVideo == null) return null;

    // Prefer HLS (includes audio), fallback to DASH
    return redditVideo['hls_url'] as String? ??
           redditVideo['fallback_url'] as String?;
  }

  /// Extract and decode selftext
  static String? _extractSelftext(Map<String, dynamic> data) {
    final selftext = data['selftext'];
    if (selftext == null || (selftext as String).isEmpty) return null;
    return HtmlUtils.decodeHtmlEntities(selftext);
  }

  /// Extract gallery images from Reddit gallery posts
  static List<String> _extractGalleryImages(Map<String, dynamic> data) {
    if (data['is_gallery'] != true) return [];

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
    // Gallery post (multiple images)
    if (galleryImages.isNotEmpty) {
      return PostContentType.gallery;
    }

    // Text post (self post)
    if (url == null || domain.contains('reddit.com')) {
      return PostContentType.text;
    }

    // Reddit-hosted video (check isVideo flag FIRST to prevent misclassification)
    if (isVideo) {
      return PostContentType.redditVideo;
    }

    // YouTube video
    if (youtubeId != null) {
      return PostContentType.youtubeVideo;
    }

    // Direct image URL
    if (UrlUtils.isImageUrl(url!)) {
      return PostContentType.image;
    }

    // External video (non-YouTube)
    if (UrlUtils.isVideoUrl(url!)) {
      return PostContentType.video;
    }

    // External link (articles, etc.)
    return PostContentType.externalLink;
  }
}
