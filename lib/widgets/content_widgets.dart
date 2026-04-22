import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/url_utils.dart';

/// Content display widgets (images, links, metadata, engagement)
class ContentWidgets {
  const ContentWidgets._(); // Private constructor to prevent instantiation
  /// External link preview widget with favicon and domain
  static Widget externalLinkPreview({
    required BuildContext context,
    required String url,
    required String domain,
    required VoidCallback onTap,
  }) {
    final colors = ThemeHelper(context);
    final faviconUrl = Uri.https(
      'www.google.com',
      '/s2/favicons',
      {
        'domain': UrlUtils.extractDomain(url, fallback: domain),
        'sz': '32',
      },
    ).toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing3,
          vertical: AppTheme.spacing2,
        ),
        decoration: BoxDecoration(
          color: colors.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: colors.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Favicon
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: faviconUrl,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 20,
                  height: 20,
                  color: colors.dividerColor,
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: colors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing2),
            // Domain
            Expanded(
              child: Text(
                domain,
                style: colors.theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.spacing2),
            // External link icon
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Engagement metrics row (upvotes and comments)
  static Widget engagementMetrics({
    required BuildContext context,
    required int score,
    required int commentCount,
    double iconSize = 16,
  }) {
    final colors = ThemeHelper(context);

    return Row(
      children: [
        Icon(
          Icons.arrow_upward_rounded,
          size: iconSize,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppTheme.spacing1),
        Text(
          FormatUtils.formatNumber(score),
          style: colors.theme.textTheme.labelMedium,
        ),
        const SizedBox(width: AppTheme.spacing4),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: iconSize,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppTheme.spacing1),
        Text(
          FormatUtils.formatNumber(commentCount),
          style: colors.theme.textTheme.labelMedium,
        ),
      ],
    );
  }

  /// Metadata row for posts (subreddit • author • time)
  static Widget postMetadata({
    required BuildContext context,
    required String subreddit,
    required String author,
    required String timeAgo,
    VoidCallback? onSubredditTap,
    VoidCallback? onAuthorTap,
  }) {
    final colors = ThemeHelper(context);
    final label = colors.theme.textTheme.labelMedium;

    return Row(
      children: [
        GestureDetector(
          onTap: onSubredditTap,
          child: Text(
            'r/$subreddit',
            style: label?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        bullet(colors),
        GestureDetector(
          onTap: onAuthorTap,
          child: Text(
            'u/$author',
            style: label?.copyWith(color: colors.textSecondary),
          ),
        ),
        bullet(colors),
        Text(timeAgo, style: label?.copyWith(color: colors.textTertiary)),
      ],
    );
  }

  /// Bulleted separator ( • ) with horizontal spacing, used between inline
  /// metadata items. Public so other metadata rows (comment header, etc.)
  /// stay visually aligned.
  static Widget bullet(ThemeHelper colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
      child: Text(
        '•',
        style: colors.theme.textTheme.labelMedium?.copyWith(
          color: colors.textTertiary,
        ),
      ),
    );
  }

  /// Cached network image with consistent placeholder and error handling.
  /// Caps in-memory decode size at screen-width × devicePixelRatio to keep
  /// feed thumbnails from holding full-resolution bitmaps in RAM.
  static Widget cachedImage({
    required BuildContext context,
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double? aspectRatio,
    BorderRadius? borderRadius,
  }) {
    final colors = ThemeHelper(context);
    final media = MediaQuery.of(context);
    final memCacheWidth = (media.size.width * media.devicePixelRatio).round();

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      maxWidthDiskCache: memCacheWidth,
      placeholder: (context, url) => Container(
        color: colors.dividerColor,
        child: Center(
          child: CircularProgressIndicator(
            color: colors.accentColor,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: colors.dividerColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_rounded,
                color: colors.textTertiary,
                size: 48,
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                'Failed to load image',
                style: colors.theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (aspectRatio != null) {
      imageWidget = AspectRatio(
        aspectRatio: aspectRatio,
        child: imageWidget,
      );
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
