import 'package:html/dom.dart';

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

  /// Parse a subreddit from an old.reddit `/subreddits/search` result
  /// (`div.thing.subreddit`). old.reddit's search rows omit icons and don't
  /// always surface a subscriber count — both degrade to null/0.
  factory Subreddit.fromThing(Element thing) {
    // The canonical name lives in the title link's href (/r/<name>/); the
    // data-sr_name attribute sits on a child subscribe button, and the title
    // text is "r/<name>: <title>" — neither is a clean name on its own.
    final href = thing.querySelector('a.title')?.attributes['href'] ?? '';
    final name = _namePattern.firstMatch(href)?.group(1) ??
        thing.querySelector('[data-sr_name]')?.attributes['data-sr_name'] ??
        '';

    final desc = thing.querySelector('.description .md')?.text.trim();

    // Subscriber count, when present, reads "12,345 readers" / "subscribers".
    final match = _subscriberPattern.firstMatch(thing.text);
    final subscribers =
        int.tryParse(match?.group(1)?.replaceAll(',', '') ?? '') ?? 0;

    return Subreddit(
      displayName: name,
      subscribers: subscribers,
      description: (desc == null || desc.isEmpty) ? null : desc,
      iconUrl: null,
    );
  }

  static final _namePattern = RegExp(r'/r/([A-Za-z0-9_]{2,21})/?');
  static final _subscriberPattern =
      RegExp(r'([\d,]+)\s*(?:readers|subscribers)', caseSensitive: false);
}
