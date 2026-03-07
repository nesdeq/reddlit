import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../theme/app_theme.dart';
import '../utils/url_utils.dart';
import '../utils/media_utils.dart';
import '../constants/app_constants.dart';
import 'reddit_video_player.dart';
import 'youtube_video_player.dart';
import 'gallery_viewer.dart';
import 'content_widgets.dart';
import 'loading_widgets.dart';

/// Content preview for a post, used in both feed cards and detail view.
/// [isCompact] controls sizing: true for feed (16:9, thumbnails), false for detail (flexible height).
class ContentPreview extends StatelessWidget {
  final RedditPost post;
  final bool isCompact;

  const ContentPreview({
    super.key,
    required this.post,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (post.contentType) {
      case PostContentType.gallery:
        return GalleryViewer(
          images: post.galleryImages,
          constrainAspectRatio: isCompact,
        );

      case PostContentType.redditVideo:
        if (MediaUtils.isValidHttpUrl(post.videoUrl)) {
          return RedditVideoPlayer(videoUrl: post.videoUrl!);
        }
        return LoadingWidgets.videoError(context);

      case PostContentType.youtubeVideo:
        if (MediaUtils.isValidYoutubeId(post.youtubeId)) {
          return YoutubeVideoPlayer(youtubeId: post.youtubeId!);
        }
        return const SizedBox.shrink();

      case PostContentType.image:
        return _buildImage(context);

      case PostContentType.externalLink:
        return ContentWidgets.externalLinkPreview(
          context: context,
          url: post.url!,
          domain: post.domain,
          onTap: () => UrlUtils.openUrl(post.url!),
        );

      case PostContentType.text:
        return const SizedBox.shrink();

      case PostContentType.video:
        return _buildVideo(context);
    }
  }

  Widget _buildImage(BuildContext context) {
    if (isCompact) {
      if (!MediaUtils.hasMediaSource(post.url, post.thumbnail)) {
        return const SizedBox.shrink();
      }
      final imageUrl = post.imageUrl.isNotEmpty ? post.imageUrl : (post.thumbnail ?? '');
      return ContentWidgets.cachedImage(
        context: context,
        imageUrl: imageUrl,
        aspectRatio: 16 / 9,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      );
    }

    if (!MediaUtils.isValidUrl(post.url)) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 600),
      child: ContentWidgets.cachedImage(
        context: context,
        imageUrl: post.url!,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    if (isCompact) {
      if (!MediaUtils.isValidUrl(post.thumbnail)) return const SizedBox.shrink();
      final imageUrl = post.imageUrl.isNotEmpty ? post.imageUrl : (post.thumbnail ?? '');
      return Stack(
        alignment: Alignment.center,
        children: [
          ContentWidgets.cachedImage(
            context: context,
            imageUrl: imageUrl,
            aspectRatio: 16 / 9,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
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

    if (!MediaUtils.isValidUrl(post.url)) return const SizedBox.shrink();
    return ContentWidgets.externalLinkPreview(
      context: context,
      url: post.url!,
      domain: post.domain,
      onTap: () => UrlUtils.openUrl(post.url!),
    );
  }
}
