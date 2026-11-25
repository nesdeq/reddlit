import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/services/article_summary_service.dart';

/// Summarizes [article] against mocked Jina and OpenAI; returns the result and the OpenAI request body.
Future<(SummaryResult, Map<String, dynamic>)> _summarize(String article) async {
  late Map<String, dynamic> sent;
  final result = await http.runWithClient(
    () => ArticleSummaryService().summarizeArticle(
      url: 'https://example.com/article',
      apiKey: 'sk-test',
      language: 'English',
    ),
    () => MockClient((request) async {
      if (request.url.host == 'r.jina.ai') {
        return http.Response(
          jsonEncode({
            'data': {'content': article},
          }),
          200,
        );
      }
      expect(request.url.path, '/v1/chat/completions');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': ' A summary. '},
            },
          ],
        }),
        200,
      );
    }),
  );
  return (result, sent);
}

String _article(Map<String, dynamic> sent) =>
    ((sent['messages'] as List).last as Map)['content'] as String;

void main() {
  test('a summary asks gpt-6-luna at high effort, with room to reason', () async {
    final (result, sent) = await _summarize('Article text.');

    expect(result.summary, 'A summary.');
    expect(sent['model'], 'gpt-6-luna');
    expect(sent['reasoning_effort'], 'high');
    // The cap counts reasoning tokens; OpenAI recommends reserving at least 25,000.
    expect(sent['max_completion_tokens'], 32000);

    final developer = (sent['messages'] as List).first as Map;
    expect(developer['role'], 'developer');
    expect(developer['content'], contains('in English'));
    expect(developer['content'], contains('<article>'));
    expect(_article(sent), '<article>\nArticle text.\n</article>');
    // Rejected by the API whenever reasoning effort is not `none`.
    expect(sent.keys, isNot(anyOf(contains('temperature'), contains('top_p'))));
  });

  group('fetching the article', () {
    Future<(SummaryResult, int)> summarizeWith(List<int> jinaStatuses) async {
      var jinaRequests = 0;
      final result = await http.runWithClient(
        () => ArticleSummaryService().summarizeArticle(
          url: 'https://example.com/article',
          apiKey: 'sk-test',
          language: 'English',
        ),
        () => MockClient((request) async {
          if (request.url.host != 'r.jina.ai') {
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': 'A summary.'},
                  },
                ],
              }),
              200,
            );
          }
          final status = jinaStatuses[jinaRequests++];
          return http.Response(
            status == 200
                ? jsonEncode({
                    'data': {'content': 'Article text.'},
                  })
                : '',
            status,
          );
        }),
      );
      return (result, jinaRequests);
    }

    test('a server error is retried once, at once', () async {
      final (result, requests) = await summarizeWith([503, 200]);
      expect(result.summary, 'A summary.');
      expect(requests, 2);
    });

    test('a rate limit is reported as one, not retried', () async {
      final (result, requests) = await summarizeWith([429, 200]);
      expect(result.error, contains('rate-limiting'));
      expect(requests, 1);
    });

    test('a missing page is not retried', () async {
      final (result, requests) = await summarizeWith([404, 200]);
      expect(result.error, contains("Couldn't fetch"));
      expect(requests, 1);
    });
  });

  test('a long article reaches the model whole', () async {
    final article = '${'word ' * 40000}THE END';
    final (_, sent) = await _summarize(article);

    expect(_article(sent), '<article>\n$article\n</article>');
  });
}
