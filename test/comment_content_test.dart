import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/screens/post_detail_screen.dart';
import 'package:reddlit/services/request_pipeline.dart';
import 'package:reddlit/widgets/comment_content.dart';

final _requested = <String>[];

// The pipeline singleton binds this client on first use: a share link redirects, pages fail.
http.Client _client() => MockClient((request) async {
      _requested.add(request.url.toString());
      return request.url.path == '/r/s/s/tok'
          ? http.Response('', 301, headers: {
              'location': 'https://www.reddit.com/r/s/comments/p5/t/?share_id=1',
            })
          : http.Response('', 404);
    });

void main() {
  setUp(_requested.clear);

  Future<void> tapLink(WidgetTester tester, String url) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CommentContent(content: '[link]($url)')),
    ));
    await tester.tapAt(
      tester.getTopLeft(find.byType(CommentContent)) + const Offset(8, 8),
    );
    // The tap resolves once a double tap is ruled out; each request then waits its gap.
    for (var i = 0; i < 3; i++) {
      await tester.pump(RequestPipeline.minGap);
    }
  }

  testWidgets('a reddit link inside a comment opens in the app', (tester) async {
    await http.runWithClient(() async {
      await tapLink(
          tester, 'https://np.reddit.com/r/s/comments/p4/t/c1/?context=2');

      expect(find.byType(PostDetailScreen), findsOneWidget);
      expect(_requested, [
        'https://old.reddit.com/r/s/comments/p4/t/c1/?sort=confidence&context=2',
      ]);
    }, _client);
  });

  testWidgets('a share link opens the thread it redirects to', (tester) async {
    await http.runWithClient(() async {
      await tapLink(tester, 'https://www.reddit.com/r/s/s/tok');

      expect(find.byType(PostDetailScreen), findsOneWidget);
      expect(_requested, [
        'https://www.reddit.com/r/s/s/tok',
        'https://old.reddit.com/r/s/comments/p5/t/?sort=confidence',
      ]);
    }, _client);
  });
}
