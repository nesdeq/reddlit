/// Shared realistic browser headers for all outgoing HTTP requests.
/// Consistent across services to avoid fingerprinting inconsistencies.
class HttpConstants {
  const HttpConstants._();

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Realistic browser headers for web requests (Reddit API, article fetching).
  /// Note: Accept-Encoding is intentionally omitted — Dart's HTTP client
  /// handles gzip/deflate transparently and auto-decompresses responses.
  /// Setting it explicitly disables auto-decompression in dart:io.
  static const Map<String, String> browserHeaders = {
    'User-Agent': _userAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
    'DNT': '1',
    'Sec-CH-UA':
        '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
    'Sec-CH-UA-Mobile': '?0',
    'Sec-CH-UA-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };
}
