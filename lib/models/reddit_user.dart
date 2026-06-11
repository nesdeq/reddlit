import 'package:html/dom.dart';
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

  /// Parse karma and cake-day from an old.reddit `/user/<name>/` page sidebar.
  factory RedditUser.fromUserPage(Document doc, String name) {
    int karma(Element? el) =>
        int.tryParse((el?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // Two `.karma` spans: post karma (plain) and comment karma (.comment-karma).
    final commentSpan = doc.querySelector('span.karma.comment-karma');
    Element? linkSpan;
    for (final span in doc.querySelectorAll('span.karma')) {
      if (!span.classes.contains('comment-karma')) {
        linkSpan = span;
        break;
      }
    }

    final age = doc.querySelector('.age time')?.attributes['datetime'];

    return RedditUser(
      name: name,
      linkKarma: karma(linkSpan),
      commentKarma: karma(commentSpan),
      created: FormatUtils.fromIso8601(age),
    );
  }

  /// Create an empty user object for error states
  factory RedditUser.empty(String name) {
    return RedditUser(
      name: name,
      linkKarma: 0,
      commentKarma: 0,
      created: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  int get totalKarma => linkKarma + commentKarma;
}
