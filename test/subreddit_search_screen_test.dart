import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/screens/subreddit_search_screen.dart';

// The pipeline singleton binds the first zone's client, so every test answers
// through this switchable handler.
late Future<http.Response> Function() _respond;
http.Client _client() => MockClient((_) => _respond());

Future<void> _search(WidgetTester tester, String query) async {
  await tester.pumpWidget(const MaterialApp(home: SubredditSearchScreen()));
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('a failed search offers retry, not "No subreddits found"',
      (tester) async {
    _respond = () async => http.Response('', 404);
    await http.runWithClient(() async {
      await _search(tester, 'cats');
      expect(find.text('No subreddits found'), findsNothing);
      expect(find.text('Failed to search subreddits.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }, _client);
  });

  testWidgets('clearing the field drops the search still in flight',
      (tester) async {
    final reply = Completer<http.Response>();
    _respond = () => reply.future;
    await http.runWithClient(() async {
      await _search(tester, 'cats');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Type to search subreddits by name'), findsOneWidget);

      reply.complete(http.Response('', 404));
      await tester.pump();
      expect(find.text('Type to search subreddits by name'), findsOneWidget);
      expect(find.text('Failed to search subreddits.'), findsNothing);
    }, _client);
  });
}
