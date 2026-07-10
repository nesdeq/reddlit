import 'package:html/dom.dart';

import 'url_utils.dart';

/// Converts the rendered HTML that old.reddit serves inside `.md` blocks back
/// into Markdown, so the existing flutter_markdown rendering path keeps working.
///
/// Reddit's `.md` output is a constrained subset (paragraphs, links, emphasis,
/// quotes, lists, code, headings, tables, images), which makes a focused
/// recursive walk reliable. Anything unrecognized degrades to its text.
class HtmlToMarkdown {
  const HtmlToMarkdown._();

  /// Guards the recursive walk: a comment with thousands of nested
  /// blockquotes/lists/spans would otherwise overflow the stack. Real reddit
  /// `.md` never approaches this; markup deeper than the cap degrades to empty.
  static const int _maxDepth = 64;

  /// Convert the children of [root] (typically a `div.md`) to Markdown.
  static String convert(Element root) {
    final blocks = _blocks(root.nodes, indent: '', depth: 0);
    return blocks.join('\n\n').trim();
  }

  /// Render a node list as a sequence of block-level Markdown strings.
  static List<String> _blocks(
    List<Node> nodes, {
    required String indent,
    required int depth,
  }) {
    final out = <String>[];
    for (final node in nodes) {
      if (node is Element) {
        final block = _block(node, indent: indent, depth: depth);
        if (block.trim().isNotEmpty) out.add(block);
      } else if (node is Text) {
        if (node.text.trim().isEmpty) continue;
        out.add(_collapse(node.text));
      }
    }
    return out;
  }

  static String _block(Element el, {required String indent, required int depth}) {
    if (depth >= _maxDepth) return '';
    switch (el.localName) {
      case 'p':
        return _inline(el.nodes, depth: depth + 1);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(el.localName!.substring(1));
        return '${'#' * level} ${_inline(el.nodes, depth: depth + 1)}';
      case 'hr':
        return '---';
      case 'br':
        return '';
      case 'blockquote':
        // Prefix every line of the inner blocks with "> ".
        final inner =
            _blocks(el.nodes, indent: indent, depth: depth + 1).join('\n\n');
        return inner
            .split('\n')
            .map((l) => l.isEmpty ? '>' : '> $l')
            .join('\n');
      case 'ul':
        return _list(el, indent: indent, ordered: false, depth: depth + 1);
      case 'ol':
        return _list(el, indent: indent, ordered: true, depth: depth + 1);
      case 'pre':
        // <pre><code>…</code></pre> → fenced block. Preserve raw whitespace.
        final code = _boundedText(el, depth).replaceAll(RegExp(r'\n$'), '');
        return '```\n$code\n```';
      case 'table':
        return _table(el, depth: depth + 1);
      case 'div':
        // Reddit wraps with <div class="md"> and occasional plain divs.
        return _blocks(el.nodes, indent: indent, depth: depth + 1).join('\n\n');
      default:
        // Inline-level element appearing at block scope → treat as a paragraph.
        return _inline([el], depth: depth + 1);
    }
  }

  static String _list(
    Element el, {
    required String indent,
    required bool ordered,
    required int depth,
  }) {
    if (depth >= _maxDepth) return '';
    final lines = <String>[];
    var i = 1;
    for (final li in el.children.where((c) => c.localName == 'li')) {
      final marker = ordered ? '${i++}.' : '-';
      // Inline content of the item, minus any nested lists.
      final inlineNodes =
          li.nodes.where((n) => !(n is Element && _isList(n))).toList();
      final text = _inline(inlineNodes, depth: depth + 1);
      lines.add('$indent$marker $text');
      // Nested lists indented under the item.
      for (final child in li.children.where(_isList)) {
        lines.add(_list(child,
            indent: '$indent    ',
            ordered: child.localName == 'ol',
            depth: depth + 1));
      }
    }
    return lines.join('\n');
  }

  static bool _isList(Element e) => e.localName == 'ul' || e.localName == 'ol';

  /// Depth-bounded text content. Plain `el.text` recurses the whole subtree and
  /// overflows on adversarially nested markup (e.g. a link wrapping thousands of
  /// nested spans); this stops at [_maxDepth].
  static String _boundedText(Element el, int depth) {
    if (depth >= _maxDepth) return '';
    final buf = StringBuffer();
    for (final node in el.nodes) {
      if (node is Text) {
        buf.write(node.text);
      } else if (node is Element) {
        buf.write(_boundedText(node, depth + 1));
      }
    }
    return buf.toString();
  }

  static String _table(Element table, {required int depth}) {
    final rows = <List<String>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.children
          .where((c) => c.localName == 'td' || c.localName == 'th')
          .map((c) => _inline(c.nodes, depth: depth + 1).replaceAll('|', r'\|'))
          .toList();
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.isEmpty) return '';
    final width = rows.first.length;
    final buf = StringBuffer();
    buf.writeln('| ${rows.first.join(' | ')} |');
    buf.writeln('| ${List.filled(width, '---').join(' | ')} |');
    for (final row in rows.skip(1)) {
      buf.writeln('| ${row.join(' | ')} |');
    }
    return buf.toString().trimRight();
  }

  /// Render a node list as inline Markdown (no block separators).
  static String _inline(List<Node> nodes, {required int depth}) {
    final buf = StringBuffer();
    for (final node in nodes) {
      if (node is Text) {
        buf.write(_collapse(node.text));
      } else if (node is Element) {
        buf.write(_inlineElement(node, depth: depth));
      }
    }
    return buf.toString();
  }

  static String _inlineElement(Element el, {required int depth}) {
    if (depth >= _maxDepth) return '';
    switch (el.localName) {
      case 'a':
        final href = el.attributes['href'] ?? '';
        final image = _asImageUrl(href);
        if (image != null) return '![${_boundedText(el, depth).trim()}]($image)';
        final text = _inline(el.nodes, depth: depth + 1);
        return href.isEmpty ? text : '[$text]($href)';
      case 'strong':
      case 'b':
        return '**${_inline(el.nodes, depth: depth + 1)}**';
      case 'em':
      case 'i':
        return '*${_inline(el.nodes, depth: depth + 1)}*';
      case 'del':
      case 'strike':
        return '~~${_inline(el.nodes, depth: depth + 1)}~~';
      case 'sup':
        return '^${_inline(el.nodes, depth: depth + 1)}';
      case 'code':
        return '`${_boundedText(el, depth)}`';
      case 'br':
        return '  \n';
      case 'img':
        final raw = el.attributes['src'] ?? '';
        final alt = el.attributes['alt'] ?? '';
        final src = _asImageUrl(raw) ?? raw;
        return src.isEmpty ? '' : '![$alt]($src)';
      default:
        return _inline(el.nodes, depth: depth + 1);
    }
  }

  static String? _asImageUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith(_giphyPrefix)) {
      final id = url.substring(_giphyPrefix.length).split('|').first;
      return id.isEmpty ? null : 'https://i.giphy.com/media/$id/giphy.gif';
    }
    if (url.startsWith('//')) url = 'https:$url';
    final giphyId = _giphyPageId(url);
    if (giphyId != null) return 'https://i.giphy.com/media/$giphyId/giphy.gif';
    return UrlUtils.isImageUrl(url) ? url : null;
  }

  static String? _giphyPageId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host != 'giphy.com' && !host.endsWith('.giphy.com')) return null;
    if (!uri.path.contains('/gifs/') || uri.pathSegments.isEmpty) return null;
    final id = uri.pathSegments.last.split('-').last;
    return id.isEmpty ? null : id;
  }

  static const String _giphyPrefix = 'giphy|';

  /// Collapse runs of insignificant HTML whitespace to single spaces.
  static String _collapse(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ');
}
