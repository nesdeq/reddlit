import 'package:html/dom.dart';

/// Converts the rendered HTML that old.reddit serves inside `.md` blocks back
/// into Markdown, so the existing flutter_markdown rendering path keeps working.
///
/// Reddit's `.md` output is a constrained subset (paragraphs, links, emphasis,
/// quotes, lists, code, headings, tables, images), which makes a focused
/// recursive walk reliable. Anything unrecognized degrades to its text.
class HtmlToMarkdown {
  const HtmlToMarkdown._();

  /// Convert the children of [root] (typically a `div.md`) to Markdown.
  static String convert(Element root) {
    final blocks = _blocks(root.nodes, indent: '');
    return blocks.join('\n\n').trim();
  }

  /// Render a node list as a sequence of block-level Markdown strings.
  static List<String> _blocks(List<Node> nodes, {required String indent}) {
    final out = <String>[];
    for (final node in nodes) {
      if (node is Element) {
        final block = _block(node, indent: indent);
        if (block != null && block.trim().isNotEmpty) out.add(block);
      } else if (node is Text) {
        final t = _collapse(node.text);
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  static String? _block(Element el, {required String indent}) {
    switch (el.localName) {
      case 'p':
        return _inline(el.nodes);
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(el.localName!.substring(1));
        return '${'#' * level} ${_inline(el.nodes)}';
      case 'hr':
        return '---';
      case 'br':
        return '';
      case 'blockquote':
        // Prefix every line of the inner blocks with "> ".
        final inner = _blocks(el.nodes, indent: indent).join('\n\n');
        return inner
            .split('\n')
            .map((l) => l.isEmpty ? '>' : '> $l')
            .join('\n');
      case 'ul':
        return _list(el, indent: indent, ordered: false);
      case 'ol':
        return _list(el, indent: indent, ordered: true);
      case 'pre':
        // <pre><code>…</code></pre> → fenced block. Preserve raw whitespace.
        final code = el.text.replaceAll(RegExp(r'\n$'), '');
        return '```\n$code\n```';
      case 'table':
        return _table(el);
      case 'div':
        // Reddit wraps with <div class="md"> and occasional plain divs.
        return _blocks(el.nodes, indent: indent).join('\n\n');
      default:
        // Inline-level element appearing at block scope → treat as a paragraph.
        return _inline([el]);
    }
  }

  static String _list(Element el, {required String indent, required bool ordered}) {
    final lines = <String>[];
    var i = 1;
    for (final li in el.children.where((c) => c.localName == 'li')) {
      final marker = ordered ? '${i++}.' : '-';
      // Inline content of the item, minus any nested lists.
      final inlineNodes =
          li.nodes.where((n) => !(n is Element && _isList(n))).toList();
      final text = _inline(inlineNodes);
      lines.add('$indent$marker $text');
      // Nested lists indented under the item.
      for (final child in li.children.where(_isList)) {
        lines.add(_list(child, indent: '$indent    ', ordered: child.localName == 'ol'));
      }
    }
    return lines.join('\n');
  }

  static bool _isList(Element e) => e.localName == 'ul' || e.localName == 'ol';

  static String _table(Element table) {
    final rows = <List<String>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.children
          .where((c) => c.localName == 'td' || c.localName == 'th')
          .map((c) => _inline(c.nodes).replaceAll('|', r'\|'))
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
  static String _inline(List<Node> nodes) {
    final buf = StringBuffer();
    for (final node in nodes) {
      if (node is Text) {
        buf.write(_collapse(node.text));
      } else if (node is Element) {
        buf.write(_inlineElement(node));
      }
    }
    return buf.toString();
  }

  static String _inlineElement(Element el) {
    switch (el.localName) {
      case 'a':
        final href = el.attributes['href'] ?? '';
        final text = _inline(el.nodes);
        return href.isEmpty ? text : '[$text]($href)';
      case 'strong':
      case 'b':
        return '**${_inline(el.nodes)}**';
      case 'em':
      case 'i':
        return '*${_inline(el.nodes)}*';
      case 'del':
      case 'strike':
        return '~~${_inline(el.nodes)}~~';
      case 'sup':
        return '^${_inline(el.nodes)}';
      case 'code':
        return '`${el.text}`';
      case 'br':
        return '  \n';
      case 'img':
        final src = el.attributes['src'] ?? '';
        final alt = el.attributes['alt'] ?? '';
        return src.isEmpty ? '' : '![$alt]($src)';
      default:
        return _inline(el.nodes);
    }
  }

  /// Collapse runs of insignificant HTML whitespace to single spaces.
  static String _collapse(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ');
}
