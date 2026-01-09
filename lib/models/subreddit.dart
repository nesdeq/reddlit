import '../utils/url_utils.dart';

/// Model for subreddit information from search results
class Subreddit {
  final String name;
  final String displayName;
  final int subscribers;
  final String? description;
  final String? iconUrl;
  final bool over18;

  Subreddit({
    required this.name,
    required this.displayName,
    required this.subscribers,
    this.description,
    this.iconUrl,
    required this.over18,
  });

  factory Subreddit.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return Subreddit(
      name: data['name'] ?? '',
      displayName: data['display_name'] ?? '',
      subscribers: data['subscribers'] ?? 0,
      description: data['public_description'] ?? data['description'],
      iconUrl: UrlUtils.cleanIconUrl(data['icon_img'] ?? data['community_icon']),
      over18: data['over18'] ?? data['over_18'] ?? false,
    );
  }
}
