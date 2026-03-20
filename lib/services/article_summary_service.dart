import 'dart:convert';
import 'package:http/http.dart' as http;

class ArticleSummaryService {
  static const String _openAiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _jinaReaderBase = 'https://r.jina.ai/';

  /// Fetch article via Jina Reader and summarize. Returns summary or null if failed.
  Future<String?> summarizeArticle({
    required String url,
    required String apiKey,
    required String language,
  }) async {
    if (apiKey.isEmpty) return null;

    try {
      final content = await _fetchMarkdown(url);
      if (content == null || content.trim().isEmpty) return null;
      return await _summarize(content, apiKey, language);
    } catch (_) {
      return null;
    }
  }

  /// Fetch article as markdown via Jina Reader API
  Future<String?> _fetchMarkdown(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$_jinaReaderBase$url'),
        headers: {'Accept': 'text/plain'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      // Jina returns: Title: ...\nURL Source: ...\nMarkdown Content:\n<content>
      // Extract just the markdown content after the header
      final body = response.body;
      const marker = 'Markdown Content:';
      final markerIndex = body.indexOf(marker);
      final content = markerIndex != -1
          ? body.substring(markerIndex + marker.length).trim()
          : body.trim();

      // Limit size for LLM context
      const maxChars = 12000;
      if (content.length > maxChars) {
        return content.substring(0, maxChars);
      }
      return content;
    } catch (_) {
      return null;
    }
  }

  /// Send to LLM for summarization
  Future<String?> _summarize(String text, String apiKey, String language) async {
    try {
      final response = await http.post(
        Uri.parse(_openAiApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'gpt-5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Summarize this article in $language in 2-3 sentences. Include key numbers/dates if any. If paywalled or empty, say so briefly.',
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'reasoning_effort': 'medium',
          'max_completion_tokens': 2048,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices']?[0]?['message']?['content']?.toString().trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
