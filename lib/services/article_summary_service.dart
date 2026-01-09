import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class ArticleSummaryService {
  static const String _openAiApiUrl = 'https://api.openai.com/v1/chat/completions';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Fetch article and summarize. Returns summary or null if failed.
  Future<String?> summarizeArticle({
    required String url,
    required String apiKey,
    required String language,
  }) async {
    if (apiKey.isEmpty) return null;

    try {
      final content = await _fetchAndExtract(url);
      if (content == null || content.trim().isEmpty) return null;
      return await _summarize(content, apiKey, language);
    } catch (_) {
      return null;
    }
  }

  /// Fetch URL and extract text content
  Future<String?> _fetchAndExtract(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5,de;q=0.3',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      return _extractText(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Extract readable text from HTML
  String _extractText(String html) {
    final document = parse(html);

    // Remove junk
    document.querySelectorAll(
      'script, style, noscript, iframe, svg, canvas, '
      'nav, header, footer, aside, form, button, input, '
      '[role="navigation"], [role="banner"], [role="complementary"], '
      '[aria-hidden="true"], .ad, .ads, .advertisement, .social, .share, '
      '.cookie, .popup, .modal, .newsletter, .subscribe'
    ).forEach((e) => e.remove());

    // Try to find main content, fallback to body
    final content = document.querySelector('article')?.text ??
        document.querySelector('main')?.text ??
        document.querySelector('[role="main"]')?.text ??
        document.querySelector('.article-content, .post-content, .entry-content, .story-body')?.text ??
        document.body?.text ??
        '';

    // Clean whitespace
    var text = content
        .replaceAll(RegExp(r'[\t\r]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    // Limit size
    const maxChars = 12000;
    if (text.length > maxChars) {
      text = text.substring(0, maxChars);
    }

    return text;
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
              'content': '''Summarize this article in $language.

OUTPUT FORMAT:
- 3-5 short paragraphs, each one sentence
- Include specific numbers, dates, statistics
- First paragraph: main point
- Middle: key facts
- Last: conclusion/implication
- Separate paragraphs with blank lines

HANDLING ISSUES:
- If paywalled: summarize what's visible, note "[Paywall - partial content]"
- If login required: note "[Login wall]"
- If empty/broken: say "Could not extract article content"
- Ignore navigation, ads, cookie notices, subscribe prompts
- Focus only on the actual article text''',
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'reasoning_effort': 'minimal',
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
