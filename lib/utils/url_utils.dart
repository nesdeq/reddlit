import 'package:url_launcher/url_launcher.dart';

/// Utility functions for URL operations
class UrlUtils {
  const UrlUtils._(); // Private constructor to prevent instantiation
  /// Check if a URL points to an image
  static bool isImageUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Exact-host suffix match to avoid matching e.g. "imgur.com.evil.tld".
    // redd.it subdomains are scoped to image hosts (not v.redd.it video).
    final host = uri.host.toLowerCase();
    const imageHosts = [
      'preview.redd.it',
      'i.redd.it',
      'imgur.com',
      'giphy.com',
    ];
    for (final h in imageHosts) {
      if (host == h || host.endsWith('.$h')) return true;
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
  static final _youtubePatterns = [
    RegExp(r'youtube\.com/watch\?v=([^&]+)'),
    RegExp(r'youtu\.be/([^?]+)'),
    RegExp(r'youtube\.com/embed/([^?]+)'),
    RegExp(r'youtube\.com/v/([^?]+)'),
    RegExp(r'youtube\.com/shorts/([^?/]+)'),
  ];

  static String? extractYoutubeId(String url) {
    for (final pattern in _youtubePatterns) {
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
    } catch (_) {
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
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
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
