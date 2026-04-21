import '../utils/html_utils.dart';
import '../utils/format_utils.dart';

class RedditComment {
  final String id;
  final String author;
  final String body;
  final int score;
  final DateTime created;
  final int depth;
  final String? parentId;
  final List<RedditComment> replies;

  /// True when this node represents a Reddit "more" placeholder — tap to fetch
  /// [moreChildrenIds] via the morechildren API.
  final bool isMorePlaceholder;
  final List<String> moreChildrenIds;

  RedditComment({
    required this.id,
    required this.author,
    required this.body,
    required this.score,
    required this.created,
    required this.depth,
    this.parentId,
    this.replies = const [],
    this.isMorePlaceholder = false,
    this.moreChildrenIds = const [],
  });

  factory RedditComment.fromJson(Map<String, dynamic> json, {int depth = 0}) {
    final kind = json['kind'];
    final data = json['data'] as Map<String, dynamic>;

    if (kind == 'more') {
      final children = (data['children'] as List?)?.cast<String>() ?? const [];
      return RedditComment(
        id: data['id']?.toString() ?? 'more_${children.hashCode}',
        author: '',
        body: '',
        score: 0,
        created: DateTime.now(),
        depth: depth,
        parentId: data['parent_id']?.toString(),
        isMorePlaceholder: true,
        moreChildrenIds: children,
      );
    }

    List<RedditComment> replies = const [];
    final repliesRaw = data['replies'];
    if (repliesRaw is Map) {
      final repliesData = repliesRaw['data'];
      final children = repliesData?['children'];
      if (children is List) {
        replies = children
            .where((r) => r['kind'] == 't1' || r['kind'] == 'more')
            .map((r) => RedditComment.fromJson(r, depth: depth + 1))
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
      parentId: data['parent_id']?.toString(),
      replies: replies,
    );
  }

  RedditComment copyWith({
    List<RedditComment>? replies,
    int? depth,
  }) {
    return RedditComment(
      id: id,
      author: author,
      body: body,
      score: score,
      created: created,
      depth: depth ?? this.depth,
      parentId: parentId,
      replies: replies ?? this.replies,
      isMorePlaceholder: isMorePlaceholder,
      moreChildrenIds: moreChildrenIds,
    );
  }
}
