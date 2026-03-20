import '../utils/url_utils.dart';

/// Model for subreddit information from search results
class Subreddit {
  final String displayName;
  final int subscribers;
  final String? description;
  final String? iconUrl;

  Subreddit({
    required this.displayName,
    required this.subscribers,
    this.description,
    this.iconUrl,
  });

  factory Subreddit.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return Subreddit(
      displayName: data['display_name'] ?? '',
      subscribers: data['subscribers'] ?? 0,
      description: data['public_description'] ?? data['description'],
      iconUrl: UrlUtils.cleanIconUrl(data['icon_img'] ?? data['community_icon']),
    );
  }
}
