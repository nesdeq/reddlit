import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:reddlit/models/reddit_post.dart';
import 'package:reddlit/widgets/content_preview.dart';

RedditPost _post({
  required String url,
  String? thumbnail,
  bool isGallery = false,
  List<String> galleryImages = const [],
}) => RedditPost(
  id: 'p',
  title: 'T',
  author: 'u',
  subreddit: 'pics',
  score: 1,
  numComments: 0,
  created: DateTime(2020),
  url: url,
  thumbnail: thumbnail,
  isVideo: false,
  isGallery: isGallery,
  galleryImages: galleryImages,
  domain: isGallery ? 'old.reddit.com' : 'i.redd.it',
);

Future<List<String>> _requested(
  WidgetTester tester,
  RedditPost post, {
  required bool isCompact,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [ContentPreview(post: post, isCompact: isCompact)],
        ),
      ),
    ),
  );
  return [
    for (final image in tester.widgetList<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    ))
      image.imageUrl,
  ];
}

void main() {
  const galleryPage = 'https://www.reddit.com/gallery/p';
  const thumbnail = 'https://preview.redd.it/deadbeef01.jpg?width=140&s=x';

  testWidgets('a gallery shows its first image in the feed, all of them opened', (
    tester,
  ) async {
    const images = [
      'https://preview.redd.it/a.jpg?width=3024&s=1',
      'https://preview.redd.it/b.jpg?width=3024&s=2',
    ];
    final post = _post(
      url: galleryPage,
      thumbnail: thumbnail,
      isGallery: true,
      galleryImages: images,
    );
    expect(await _requested(tester, post, isCompact: true), [images.first]);
    expect(await _requested(tester, post, isCompact: false), images);
  });

  testWidgets('a gallery with unknown images never loads its page as an image', (
    tester,
  ) async {
    final post = _post(url: galleryPage, thumbnail: thumbnail, isGallery: true);
    expect(await _requested(tester, post, isCompact: true), [
      'https://i.redd.it/deadbeef01.jpg',
    ]);
    expect(await _requested(tester, post, isCompact: false), isEmpty);
  });

  testWidgets('a single image is the same request in the feed and opened', (
    tester,
  ) async {
    final post = _post(url: 'https://i.redd.it/pic1.jpeg');
    expect(await _requested(tester, post, isCompact: true), [post.url]);
    expect(await _requested(tester, post, isCompact: false), [post.url]);
  });
}
