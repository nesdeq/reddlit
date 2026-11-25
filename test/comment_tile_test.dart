import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reddlit/constants/app_constants.dart';
import 'package:reddlit/models/reddit_comment.dart';
import 'package:reddlit/theme/app_theme.dart';
import 'package:reddlit/widgets/comment_content.dart';
import 'package:reddlit/widgets/comment_tile.dart';

RedditComment _comment(
  String id, {
  int depth = 0,
  String author = 'a',
  List<RedditComment> replies = const [],
}) => RedditComment(
  id: id,
  author: author,
  body: 'body $id',
  score: 1,
  created: DateTime(2020),
  depth: depth,
  replies: replies,
);

/// c0 > c1 > ... > c[last], each the only reply of the one before.
RedditComment _chain(int last) {
  var comment = _comment('c$last', depth: last, author: 'author$last');
  for (var depth = last - 1; depth >= 0; depth--) {
    comment = _comment(
      'c$depth',
      depth: depth,
      author: 'author$depth',
      replies: [comment],
    );
  }
  return comment;
}

void main() {
  Future<void> show(WidgetTester tester, RedditComment c) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommentTile(key: const ValueKey('c'), comment: c),
        ),
      ),
    ),
  );

  testWidgets('a collapsed comment counts the replies it has now', (
    tester,
  ) async {
    await show(tester, _comment('c', replies: [_comment('r1', depth: 1)]));
    await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);

    await show(
      tester,
      _comment(
        'c',
        replies: [
          _comment('r1', depth: 1),
          _comment('r2', depth: 1, replies: [_comment('r3', depth: 2)]),
        ],
      ),
    );
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('a deep thread opens fully and keeps its text column on a phone', (
    tester,
  ) async {
    const phoneWidth = 360.0;
    await tester.binding.setSurfaceSize(const Size(phoneWidth, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await show(tester, _chain(12));

    expect(find.text('body c12'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('c12'))).width,
      phoneWidth -
          2 * AppTheme.spacing4 -
          AppConstants.commentMaxIndentDepth * AppConstants.commentIndentStep,
    );
  });

  testWidgets('each level indents one step past its parent', (tester) async {
    await show(tester, _chain(2));
    double left(String id) =>
        tester.getTopLeft(find.widgetWithText(CommentContent, 'body $id')).dx;

    expect(left('c1') - left('c0'), AppConstants.commentIndentStep);
    expect(left('c2') - left('c1'), AppConstants.commentIndentStep);
  });

  testWidgets('past the last indent a reply names the comment it answers', (
    tester,
  ) async {
    final last = AppConstants.commentMaxIndentDepth + 1;
    await show(tester, _chain(last));

    expect(find.text('u/author${last - 1}'), findsOneWidget);
    expect(find.text('u/author${last - 2}'), findsNothing);
  });
}
