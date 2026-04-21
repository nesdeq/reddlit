import 'dart:convert';

import 'package:http/http.dart' as http;

/// Outcome of a summarize call. On failure [error] carries a short,
/// user-facing string identifying which step failed (fetch vs summarize).
class SummaryResult {
  final String? summary;
  final String? error;
  const SummaryResult._(this.summary, this.error);
  const SummaryResult.success(String text) : this._(text, null);
  const SummaryResult.failure(String msg) : this._(null, msg);
  bool get isSuccess => summary != null;
}

/// Article summarizer: Jina Reader fetches the content, OpenAI writes the
/// summary. We never scrape directly — Jina is the one source of truth.
class ArticleSummaryService {
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _jinaBase = 'https://r.jina.ai/';
  static const int _maxChars = 12000;
  static const Duration _jinaTimeout = Duration(seconds: 45);
  static const Duration _openAiTimeout = Duration(seconds: 30);

  Future<SummaryResult> summarizeArticle({
    required String url,
    required String apiKey,
    required String language,
  }) async {
    if (apiKey.isEmpty) {
      return const SummaryResult.failure('API key not configured.');
    }

    final content = await _fetchMarkdown(url);
    if (content == null) {
      return const SummaryResult.failure(
        "Couldn't fetch the article. The site may be paywalled, rate-limited, "
        'or unreachable via Jina Reader.',
      );
    }
    if (content.trim().isEmpty) {
      return const SummaryResult.failure(
        'Jina returned no content — the article is likely paywalled or empty.',
      );
    }

    final summary = await _summarize(content, apiKey, language);
    if (summary == null || summary.isEmpty) {
      return const SummaryResult.failure(
        'Summarization failed. Check your OpenAI API key and network.',
      );
    }
    return SummaryResult.success(summary);
  }

  /// Fetch markdown content via Jina Reader.
  ///
  /// The target URL is percent-encoded as a single path segment so its own
  /// `?` and `&` don't get swallowed by Dart's Uri parser as Jina's query —
  /// that bug silently broke any article whose URL carried query parameters.
  Future<String?> _fetchMarkdown(String url) async {
    final jinaUri = Uri.parse('$_jinaBase${Uri.encodeComponent(url)}');

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .get(
              jinaUri,
              headers: const {
                'Accept': 'application/json',
                'X-Return-Format': 'markdown',
              },
            )
            .timeout(_jinaTimeout);

        if (response.statusCode == 200) {
          return _extractContent(response.body);
        }
        // 5xx / 429 → transient, retry once. Other codes are terminal.
        final transient = response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode < 600);
        if (!transient) return null;
      } catch (_) {
        // Timeout or network error — retry once.
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  /// Extract the markdown body from Jina's JSON response, trimming to the
  /// LLM context budget.
  String? _extractContent(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      final content = data['content']?.toString() ?? '';
      if (content.length > _maxChars) return content.substring(0, _maxChars);
      return content;
    } catch (_) {
      return null;
    }
  }

  /// Summarize via OpenAI. `reasoning_effort: minimal` — summarization
  /// doesn't need reasoning and the latency gain is substantial.
  Future<String?> _summarize(
    String text,
    String apiKey,
    String language,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(_openAiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: json.encode({
              'model': 'gpt-5-mini',
              'messages': [
                {
                  'role': 'developer',
                  'content': _systemPrompt(language),
                },
                {'role': 'user', 'content': text},
              ],
              'reasoning_effort': 'minimal',
              'max_completion_tokens': 2048,
            }),
          )
          .timeout(_openAiTimeout);

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      return data['choices']?[0]?['message']?['content']?.toString().trim();
    } catch (_) {
      return null;
    }
  }

  String _systemPrompt(String language) =>
      'Summarize this article. Write spare, declarative prose in the manner '
      'of Cormac McCarthy. No adverbs. No hedging. No preamble. No '
      'meta-commentary. Short sentences. State what happened. Keep numbers, '
      'names, and dates exact. Three to four sentences total.\n\n'
      'Respond in $language. If the content is empty or paywalled, say so in '
      'one sentence and stop.';
}
