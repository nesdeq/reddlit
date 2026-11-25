import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/services/article_summary_service.dart';

void main() {
  test('a summary asks gpt-6-luna at high effort, with room to reason', () async {
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
              'data': {'content': 'Article text.'},
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

    expect(result.summary, 'A summary.');
    expect(sent['model'], 'gpt-6-luna');
    expect(sent['reasoning_effort'], 'high');
    // The cap counts reasoning tokens; OpenAI recommends reserving at least 25,000.
    expect(sent['max_completion_tokens'], 32000);

    final [developer, user] = (sent['messages'] as List).cast<Map>();
    expect(developer['role'], 'developer');
    expect(developer['content'], contains('in English'));
    expect(developer['content'], contains('<article>'));
    expect(user['content'], '<article>\nArticle text.\n</article>');
    // Rejected by the API whenever reasoning effort is not `none`.
    expect(sent.keys, isNot(anyOf(contains('temperature'), contains('top_p'))));
  });
}
