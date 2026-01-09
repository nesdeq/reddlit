import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/url_utils.dart';
import '../utils/media_utils.dart';
import '../constants/app_constants.dart';

/// Jony Ive principle: Content speaks for itself
/// Parse Reddit content: extract images/GIFs FIRST, then apply markdown to text
class CommentContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  // Pre-compiled regex patterns for better performance (static final)
  static final _gifPattern = RegExp(r'!\[gif\]\(giphy\|([A-Za-z0-9]+)(?:\|[^\)]+)?\)');
  static final _standaloneUrlPattern = RegExp(r'(?<!\]\()(?<!\()https?://[^\s\)]+', caseSensitive: false);

  const CommentContent({
    super.key,
    required this.content,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final processedContent = _processContent(content);

    return MarkdownBody(
      data: processedContent,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          UrlUtils.openUrl(href);
        }
      },
      builders: {
        'image': CustomImageBuilder(colors),
      },
      styleSheet: MarkdownStyleSheet(
        p: textStyle ?? colors.theme.textTheme.bodyMedium,
        h1: colors.theme.textTheme.displayMedium,
        h2: colors.theme.textTheme.titleLarge,
        h3: colors.theme.textTheme.titleMedium,
        a: (textStyle ?? colors.theme.textTheme.bodyMedium)?.copyWith(
          color: colors.accentColor,
          decoration: TextDecoration.underline,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: colors.dividerColor.withValues(alpha: AppConstants.codeBackgroundOpacity),
          color: colors.textPrimary,
          fontSize: (textStyle?.fontSize ?? 15) * 0.9,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.dividerColor.withValues(alpha: AppConstants.codeBackgroundOpacity),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        blockquote: (textStyle ?? colors.theme.textTheme.bodyMedium)?.copyWith(
          color: colors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: colors.dividerColor, width: 3),
          ),
        ),
        listBullet: (textStyle ?? colors.theme.textTheme.bodyMedium)?.copyWith(
          color: colors.textSecondary,
        ),
        em: (textStyle ?? colors.theme.textTheme.bodyMedium)?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        strong: (textStyle ?? colors.theme.textTheme.bodyMedium)?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        blockSpacing: AppTheme.spacing2,
        listIndent: AppTheme.spacing4,
        blockquotePadding: const EdgeInsets.only(left: AppTheme.spacing3),
        codeblockPadding: const EdgeInsets.all(AppTheme.spacing3),
      ),
    );
  }

  /// Process content: Convert Reddit GIFs and standalone images to markdown syntax
  String _processContent(String text) {
    // STEP 1: Convert Reddit GIF syntax to markdown images
    // ![gif](giphy|ID) -> ![gif](https://i.giphy.com/media/ID/giphy.gif)
    String processed = text.replaceAllMapped(_gifPattern, (match) =>
      '![gif](https://i.giphy.com/media/${match.group(1)}/giphy.gif)');

    // STEP 2: Convert standalone image URLs (not in markdown) to markdown images
    // Only convert if it's an image URL
    return processed.replaceAllMapped(_standaloneUrlPattern, (match) {
      final url = match.group(0)!;
      return UrlUtils.isImageUrl(url) ? '![]($url)' : url;
    });
  }
}

/// Custom image builder for markdown with better caching and error handling
class CustomImageBuilder extends MarkdownElementBuilder {
  final ThemeHelper colors;

  CustomImageBuilder(this.colors);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String? src = element.attributes['src'];
    if (!MediaUtils.isValidImageSource(src)) {
      return null;
    }

    // MediaUtils.isValidImageSource ensures src is non-null and non-empty
    final imageUrl = src!; // Safe after validation

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      child: GestureDetector(
        onTap: () => UrlUtils.openUrl(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 200,
              color: colors.dividerColor,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accentColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 100,
              color: colors.dividerColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: colors.textTertiary,
                      size: 32,
                    ),
                    const SizedBox(height: AppTheme.spacing1),
                    Text(
                      'Image failed to load',
                      style: colors.theme.textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
