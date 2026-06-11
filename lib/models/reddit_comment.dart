import 'package:html/dom.dart';
import '../utils/format_utils.dart';
import '../utils/html_to_markdown.dart';

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
  /// the parent thread at [morePermalink] and splice the replies in.
  final bool isMorePlaceholder;
  final List<String> moreChildrenIds;

  /// old.reddit permalink to fetch when expanding this placeholder. The JSON
  /// morechildren API is blocked, so we re-fetch the parent's HTML thread.
  final String? morePermalink;

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
    this.morePermalink,
  });

  /// Parse a single `div.thing.comment` and, recursively, its reply subtree.
  factory RedditComment.fromThing(Element thing, {int depth = 0}) {
    final fullname = thing.attributes['data-fullname'] ?? '';
    final id = fullname.startsWith('t1_') ? fullname.substring(3) : fullname;
    final permalink = thing.attributes['data-permalink'];

    return RedditComment(
      id: id,
      author: thing.attributes['data-author'] ?? '[deleted]',
      body: _extractBody(thing),
      score: _extractScore(thing),
      created: FormatUtils.fromIso8601(_directEntry(thing)
          ?.querySelector('.tagline time')
          ?.attributes['datetime']),
      depth: depth,
      parentId: fullname,
      replies: parseReplies(thing, depth + 1, permalink ?? '', fullname),
    );
  }

  /// Build a "more replies" placeholder from a `div.thing.morechildren` node.
  /// [parentPermalink]/[parentFullname] identify the thread to re-fetch.
  factory RedditComment.moreFromThing(
    Element thing, {
    required int depth,
    required String parentPermalink,
    required String parentFullname,
  }) {
    final anchor = thing.querySelector('.morecomments a, a.button');
    final onclick = anchor?.attributes['onclick'] ?? '';
    final ids = _moreIdPattern
        .allMatches(onclick)
        .map((m) => m.group(0)!)
        .toList();

    // "continue this thread →" carries a real href; "load more" uses onclick.
    final href = anchor?.attributes['href'];
    final permalink = (href != null && href.startsWith('/'))
        ? 'https://old.reddit.com$href'
        : 'https://old.reddit.com$parentPermalink';

    return RedditComment(
      id: 'more_${parentFullname}_${ids.length}',
      author: '',
      body: '',
      score: 0,
      created: DateTime.fromMillisecondsSinceEpoch(0),
      depth: depth,
      parentId: parentFullname,
      isMorePlaceholder: true,
      moreChildrenIds: ids,
      morePermalink: permalink,
    );
  }

  /// Parse the direct reply things nested under [thing]'s `.child > .sitetable`.
  static List<RedditComment> parseReplies(
    Element thing,
    int depth,
    String parentPermalink,
    String parentFullname,
  ) {
    final child = _directChild(thing, 'child');
    final sitetable = child == null ? null : _directChild(child, 'sitetable');
    if (sitetable == null) return const [];
    return parseThings(sitetable, depth, parentPermalink, parentFullname);
  }

  /// Parse the direct `.thing` children of a sitetable into comments and more
  /// placeholders. Shared by the reply walk and the top-level comment area.
  static List<RedditComment> parseThings(
    Element sitetable,
    int depth,
    String parentPermalink,
    String parentFullname,
  ) {
    final out = <RedditComment>[];
    for (final el in sitetable.children) {
      if (!el.classes.contains('thing')) continue;
      if (el.classes.contains('morechildren') || el.classes.contains('deepthread')) {
        out.add(RedditComment.moreFromThing(
          el,
          depth: depth,
          parentPermalink: parentPermalink,
          parentFullname: parentFullname,
        ));
      } else if (el.classes.contains('comment')) {
        out.add(RedditComment.fromThing(el, depth: depth));
      }
    }
    return out;
  }

  static final _moreIdPattern = RegExp(r't1_[a-z0-9]+', caseSensitive: false);

  static Element? _directChild(Element parent, String className) {
    for (final el in parent.children) {
      if (el.classes.contains(className)) return el;
    }
    return null;
  }

  /// The comment's own `.entry`, excluding nested replies (which live in
  /// `.child`). Reddit renders `.entry` as a direct child of the thing.
  static Element? _directEntry(Element thing) => _directChild(thing, 'entry');

  static String _extractBody(Element thing) {
    final md = _directEntry(thing)?.querySelector('.usertext-body .md');
    if (md == null) return '';
    return HtmlToMarkdown.convert(md);
  }

  static int _extractScore(Element thing) {
    final span = _directEntry(thing)?.querySelector('.tagline .score.unvoted');
    final title = span?.attributes['title'];
    if (title != null) return int.tryParse(title) ?? 0;
    // score-hidden comments expose no number for the first hours.
    return 0;
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
      morePermalink: morePermalink,
    );
  }
}
