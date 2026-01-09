/// Utility functions for media validation - centralized for consistency
/// Provides semantic clarity and consistent validation across the app
class MediaUtils {
  const MediaUtils._(); // Private constructor to prevent instantiation

  /// Check if video URL is valid (not null/empty and starts with http)
  static bool isValidVideoUrl(String? url) {
    return url != null && url.isNotEmpty && url.startsWith('http');
  }

  /// Check if URL is valid (not null and not empty)
  static bool isValidUrl(String? url) {
    return url != null && url.isNotEmpty;
  }

  /// Check if media source (url or thumbnail) is available
  static bool hasMediaSource(String? url, String? thumbnail) {
    return (url != null && url.isNotEmpty) ||
           (thumbnail != null && thumbnail.isNotEmpty);
  }

  /// Check if YouTube ID is valid (not null and has minimum expected length)
  static bool isValidYoutubeId(String? youtubeId) {
    return youtubeId != null && youtubeId.length >= 10;
  }

  /// Check if thumbnail is valid (not null and not empty)
  static bool isValidThumbnail(String? thumbnail) {
    return thumbnail != null && thumbnail.isNotEmpty;
  }

  /// Check if image source is valid (not null/empty and starts with http)
  static bool isValidImageSource(String? src) {
    return src != null && src.isNotEmpty && src.startsWith('http');
  }
}
