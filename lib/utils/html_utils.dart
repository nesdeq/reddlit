import 'package:html/parser.dart' show parseFragment;

/// Utility functions for HTML processing
class HtmlUtils {
  const HtmlUtils._(); // Private constructor to prevent instantiation
  /// Decode HTML entities like &gt; &lt; &amp; etc.
  /// Returns the decoded text, or original text if decoding fails
  static String decodeHtmlEntities(String text) {
    if (text.isEmpty) return text;
    try {
      // Parse as HTML fragment and extract text (automatically decodes all entities)
      return parseFragment(text).text ?? text;
    } catch (_) {
      return text;
    }
  }
}
