import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/url_utils.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';

class CommentContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const CommentContent({
    super.key,
    required this.content,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          UrlUtils.openUrl(href);
        }
      },
      builders: {
        'img': CustomImageBuilder(colors),
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
}

class CustomImageBuilder extends MarkdownElementBuilder {
  final ThemeHelper colors;

  CustomImageBuilder(this.colors);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final src = element.attributes['src'];
    if (src == null || !src.startsWith('http')) return null;
    final imageUrl = src;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      child: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          final memCacheWidth =
              (media.size.width * media.devicePixelRatio).round();
          return GestureDetector(
            onTap: () => UrlUtils.openUrl(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: AuthService.instance.mediaHeaders(imageUrl),
                fit: BoxFit.cover,
                memCacheWidth: memCacheWidth,
                maxWidthDiskCache: memCacheWidth,
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
                          Icons.image_not_supported_rounded,
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
          );
        },
      ),
    );
  }
}
