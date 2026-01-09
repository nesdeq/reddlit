import 'package:url_launcher/url_launcher.dart';

/// Utility functions for URL operations
class UrlUtils {
  const UrlUtils._(); // Private constructor to prevent instantiation
  /// Check if a URL points to an image
  static bool isImageUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Reddit, Imgur, and Giphy image/media hosts
    if (uri.host.contains('preview.redd.it') ||
        uri.host.contains('i.redd.it') ||
        uri.host.contains('i.imgur.com') ||
        uri.host.contains('imgur.com') ||
        uri.host.contains('i.giphy.com') ||
        uri.host.contains('media.giphy.com')) {
      return true;
    }

    // Check file extension for direct image URLs
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  /// Check if a URL points to a video
  static bool isVideoUrl(String url) {
    return url.contains('v.redd.it') ||
        url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mov');
  }

  /// Extract YouTube video ID from various YouTube URL formats
  static String? extractYoutubeId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([^&]+)'),
      RegExp(r'youtu\.be/([^?]+)'),
      RegExp(r'youtube\.com/embed/([^?]+)'),
      RegExp(r'youtube\.com/v/([^?]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Extract domain from URL, with fallback
  static String extractDomain(String url, {String fallback = ''}) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return fallback;
    }
  }

  /// Clean icon/image URL by removing query parameters and validating format
  static String? cleanIconUrl(dynamic iconUrl) {
    if (iconUrl == null || iconUrl == '') return null;
    if (iconUrl is String && iconUrl.startsWith('http')) {
      return iconUrl.split('?').first;
    }
    return null;
  }

  /// Open URL in external browser
  static Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if URL can be summarized (external article, not media)
  static bool canSummarize(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.contains('reddit.com') || url.contains('redd.it')) return false;
    if (isImageUrl(url) || isVideoUrl(url)) return false;
    return true;
  }
}
