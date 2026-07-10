import 'package:html/dom.dart';

class Subreddit {
  final String displayName;
  final int subscribers;
  final String? description;
  final String? iconUrl;
  final String? age;

  Subreddit({
    required this.displayName,
    required this.subscribers,
    this.description,
    this.iconUrl,
    this.age,
  });

  factory Subreddit.fromThing(Element thing) {
    final href = thing.querySelector('a.title')?.attributes['href'] ?? '';
    final name = _namePattern.firstMatch(href)?.group(1) ??
        thing.querySelector('[data-sr_name]')?.attributes['data-sr_name'] ??
        '';

    final desc = thing.querySelector('.description .md')?.text.trim();

    final match = _subscriberPattern.firstMatch(thing.text);
    final subscribers =
        int.tryParse(match?.group(1)?.replaceAll(',', '') ?? '') ?? 0;

    final tagline = thing.querySelector('p.tagline')?.text.trim() ?? '';
    final age = _agePattern.firstMatch(tagline)?.group(1)?.trim();

    return Subreddit(
      displayName: name,
      subscribers: subscribers,
      description: (desc == null || desc.isEmpty) ? null : desc,
      iconUrl: null,
      age: (age == null || age.isEmpty) ? null : age,
    );
  }

  static final _namePattern = RegExp(r'/r/([A-Za-z0-9_]{2,21})/?');
  static final _subscriberPattern =
      RegExp(r'([\d,]+)\s*(?:readers|subscribers)', caseSensitive: false);
  static final _agePattern = RegExp(r'community for (.+)', caseSensitive: false);
}
