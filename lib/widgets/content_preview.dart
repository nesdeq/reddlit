import 'dart:io';

import 'package:material_ui/material_ui.dart';
import '../models/reddit_post.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_helper.dart';
import '../utils/url_utils.dart';
import '../constants/app_constants.dart';
import 'reddit_video_player.dart';
import 'youtube_video_player.dart';
import 'content_widgets.dart';
import 'loading_widgets.dart';

/// A post's media: a fixed-ratio preview in feed cards, the whole image in the detail view.
class ContentPreview extends StatelessWidget {
  final RedditPost post;
  final bool isCompact;

  const ContentPreview({super.key, required this.post, this.isCompact = true});

  @override
  Widget build(BuildContext context) {
    switch (post.contentType) {
      case PostContentType.gallery:
        if (isCompact) return _croppedImage(context, post.galleryCover!);
        return Column(
          spacing: AppTheme.spacing2,
          children: [
            for (final url in post.galleryImages) _wholeImage(context, url),
          ],
        );

      case PostContentType.redditVideo:
        final videoUrl = post.videoUrl;
        if (_videoPlayerSupported &&
            videoUrl != null &&
            videoUrl.startsWith('http')) {
          return RedditVideoPlayer(videoUrl: videoUrl);
        }
        return _videoPoster(context);

      case PostContentType.youtubeVideo:
        return YoutubeVideoPlayer(youtubeId: post.youtubeId!);

      case PostContentType.image:
        return isCompact
            ? _croppedImage(context, post.url!)
            : _wholeImage(context, post.url!);

      case PostContentType.externalLink:
        return ContentWidgets.externalLinkPreview(
          context: context,
          url: post.url!,
          domain: post.domain,
          onTap: () => UrlUtils.openUrl(post.url!),
        );

      case PostContentType.redditLink:
        final link = post.redditLink!;
        return ContentWidgets.redditLinkPreview(
          context: context,
          link: link,
          onTap: () => NavigationHelper.openLink(context, link),
        );

      case PostContentType.text:
        return const SizedBox.shrink();

      case PostContentType.video:
        return _buildVideo(context);
    }
  }

  /// The image cropped to the feed ratio.
  Widget _croppedImage(BuildContext context, String url) =>
      ContentWidgets.cachedImage(
        context: context,
        imageUrl: url,
        aspectRatio: AppConstants.feedMediaAspectRatio,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      );

  /// The image at full width and its own height, however tall.
  Widget _wholeImage(BuildContext context, String url) => SizedBox(
    width: double.infinity,
    child: ContentWidgets.cachedImage(
      context: context,
      imageUrl: url,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
  );

  Widget _buildVideo(BuildContext context) {
    if (isCompact) {
      if (!(post.thumbnail?.isNotEmpty ?? false)) {
        return const SizedBox.shrink();
      }
      return _thumbnailWithPlayButton(context, post.thumbnail!);
    }

    if (!(post.url?.isNotEmpty ?? false)) return const SizedBox.shrink();
    return ContentWidgets.externalLinkPreview(
      context: context,
      url: post.url!,
      domain: post.domain,
      onTap: () => UrlUtils.openUrl(post.url!),
    );
  }

  static final bool _videoPlayerSupported =
      !(Platform.isLinux || Platform.isWindows);

  Widget _videoPoster(BuildContext context) {
    final poster = post.thumbnail;
    final target = post.url ?? post.videoUrl;
    if (poster == null || poster.isEmpty) {
      return LoadingWidgets.videoError(context);
    }
    return GestureDetector(
      onTap: target == null ? null : () => UrlUtils.openUrl(target),
      child: _thumbnailWithPlayButton(context, poster),
    );
  }

  Widget _thumbnailWithPlayButton(BuildContext context, String imageUrl) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _croppedImage(context, imageUrl),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: AppConstants.overlayOpacity),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(AppTheme.spacing3),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }
}
