/// Utility functions for media validation - centralized for consistency
class MediaUtils {
  const MediaUtils._();

  /// Check if URL is valid (not null and not empty)
  static bool isValidUrl(String? url) {
    return url != null && url.isNotEmpty;
  }

  /// Check if URL is valid HTTP(S) URL (not null/empty and starts with http)
  static bool isValidHttpUrl(String? url) {
    return url != null && url.isNotEmpty && url.startsWith('http');
  }

  /// Check if media source (url or thumbnail) is available
  static bool hasMediaSource(String? url, String? thumbnail) {
    return isValidUrl(url) || isValidUrl(thumbnail);
  }

  /// Check if YouTube ID is valid (not null and has minimum expected length)
  static bool isValidYoutubeId(String? youtubeId) {
    return youtubeId != null && youtubeId.length >= 10;
  }
}
