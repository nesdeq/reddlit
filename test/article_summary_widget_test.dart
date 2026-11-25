import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reddlit/services/settings_provider.dart';
import 'package:reddlit/widgets/article_summary_widget.dart';

class _PageTwo extends StatelessWidget {
  const _PageTwo();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            const Text('PAGE TWO'),
            TextButton(
              onPressed: () => ArticleSummaryWidget.showSummary(
                context: context,
                url: 'https://example.com/article',
                title: 'An article',
              ),
              child: const Text('Summarize'),
            ),
          ],
        ),
      );
}

void main() {
  // Opens page two and starts a summary whose article fetch answers with [reply].
  Future<void> startSummary(
      WidgetTester tester, Completer<http.Response> reply) async {
    SharedPreferences.setMockInitialValues(
        {'openai_api_key': 'sk-test', 'openai_api_key_valid': true});
    // Settings load through the secure-storage channel, which answers only on
    // real event-loop turns.
    final settings = (await tester.runAsync(() async {
      final s = SettingsProvider();
      await s.ready;
      return s;
    }))!;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const _PageTwo()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summarize'));
    await tester.pump();
    expect(find.text('Fetching and summarizing article...'), findsOneWidget);
  }

  testWidgets('backing out of the loading dialog leaves the page in place',
      (tester) async {
    final reply = Completer<http.Response>();
    await http.runWithClient(() async {
      await startSummary(tester, reply);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Fetching and summarizing article...'), findsNothing);

      reply.complete(http.Response('', 404));
      await tester.pumpAndSettle();
      expect(find.text('PAGE TWO'), findsOneWidget);
      expect(find.text('Summary Unavailable'), findsNothing);
    }, () => MockClient((_) => reply.future));
  });

  testWidgets('a failed summary closes the loader and explains, page intact',
      (tester) async {
    final reply = Completer<http.Response>();
    await http.runWithClient(() async {
      await startSummary(tester, reply);
      reply.complete(http.Response('', 404));
      await tester.pumpAndSettle();
      expect(find.text('Fetching and summarizing article...'), findsNothing);
      expect(find.text('Summary Unavailable'), findsOneWidget);
      expect(find.text('PAGE TWO'), findsOneWidget);
    }, () => MockClient((_) => reply.future));
  });
}
