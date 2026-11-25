import 'package:html/dom.dart';

import '../utils/url_utils.dart';

class Subreddit {
  final String displayName;
  final int weeklyVisitors;
  final String? description;
  final String? iconUrl;

  Subreddit({
    required this.displayName,
    this.weeklyVisitors = 0,
    this.description,
    this.iconUrl,
  });

  /// Parse one new-reddit community-search card
  /// (`div[data-testid="search-community"]`). old.reddit's search page carries
  /// no member count and no icon, and reddit no longer exposes subscriber
  /// counts on old.reddit at all, so subreddit search alone uses new reddit,
  /// where each card exposes the name, weekly-visitor count, icon, and blurb.
  factory Subreddit.fromCommunityCard(Element card) {
    final href = card.querySelector('a[href]')?.attributes['href'] ?? '';
    final name = _namePattern.firstMatch(href)?.group(1) ?? '';

    final visitors = int.tryParse(
          card.querySelector('faceplate-number')?.attributes['number'] ?? '',
        ) ??
        0;

    final icon = UrlUtils.fromAttribute(card.querySelector('img')?.attributes['src']);

    final desc = card
        .querySelector('[data-testid="search-subreddit-desc-text"]')
        ?.text
        .trim();

    return Subreddit(
      displayName: name,
      weeklyVisitors: visitors,
      description: (desc == null || desc.isEmpty) ? null : desc,
      iconUrl: icon,
    );
  }

  /// Cards of a community-search page, ranked by weekly visitors, highest first.
  static List<Subreddit> parseSearchResults(Document doc) {
    final subs = doc
        .querySelectorAll('[data-testid="search-community"]')
        .map(Subreddit.fromCommunityCard)
        .where((s) => s.displayName.isNotEmpty)
        .toList();
    subs.sort((a, b) => b.weeklyVisitors.compareTo(a.weeklyVisitors));
    return subs;
  }

  static final _namePattern = RegExp(r'/r/([A-Za-z0-9_]{2,21})');
}
