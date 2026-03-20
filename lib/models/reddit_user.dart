import '../utils/format_utils.dart';

class RedditUser {
  final String name;
  final int linkKarma;
  final int commentKarma;
  final DateTime created;

  RedditUser({
    required this.name,
    required this.linkKarma,
    required this.commentKarma,
    required this.created,
  });

  factory RedditUser.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return RedditUser(
      name: data['name'] ?? '',
      linkKarma: data['link_karma'] ?? 0,
      commentKarma: data['comment_karma'] ?? 0,
      created: FormatUtils.fromRedditUtc(data['created_utc']),
    );
  }

  /// Create an empty user object for error states
  factory RedditUser.empty(String name) {
    return RedditUser(
      name: name,
      linkKarma: 0,
      commentKarma: 0,
      created: DateTime.now(),
    );
  }

  int get totalKarma => linkKarma + commentKarma;
}
