import '../utils/html_utils.dart';
import '../utils/format_utils.dart';

class RedditComment {
  final String id;
  final String author;
  final String body;
  final int score;
  final DateTime created;
  final int depth;
  final List<RedditComment> replies;

  RedditComment({
    required this.id,
    required this.author,
    required this.body,
    required this.score,
    required this.created,
    required this.depth,
    this.replies = const [],
  });

  factory RedditComment.fromJson(Map<String, dynamic> json, {int depth = 0}) {
    final data = json['data'];

    // Handle "more" comments placeholder
    if (data['id'] == null || json['kind'] == 'more') {
      return RedditComment(
        id: 'more_${data['count'] ?? 0}',
        author: '',
        body: '',
        score: 0,
        created: DateTime.now(),
        depth: depth,
        replies: [],
      );
    }

    List<RedditComment> replies = [];
    if (data['replies'] != null && data['replies'] is Map) {
      final repliesData = data['replies']['data'];
      if (repliesData != null && repliesData['children'] != null) {
        replies = (repliesData['children'] as List)
            .where((reply) => reply['kind'] == 't1' || reply['kind'] == 'more')
            .map((reply) => RedditComment.fromJson(reply, depth: depth + 1))
            .where((comment) => comment.body.isNotEmpty)
            .toList();
      }
    }

    return RedditComment(
      id: data['id'] ?? '',
      author: data['author'] ?? '[deleted]',
      body: HtmlUtils.decodeHtmlEntities(data['body'] ?? ''),
      score: data['score'] ?? 0,
      created: FormatUtils.fromRedditUtc(data['created_utc']),
      depth: depth,
      replies: replies,
    );
  }
}
