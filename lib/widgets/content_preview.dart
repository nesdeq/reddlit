import 'dart:io';

import 'package:flutter/material.dart';
import '../models/reddit_post.dart';
import '../theme/app_theme.dart';
import '../utils/url_utils.dart';
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

  const ContentPreview({super.key, required this.post, this.isCompact = true});

  @override
  Widget build(BuildContext context) {
    switch (post.contentType) {
      case PostContentType.gallery:
        return GalleryViewer(
          images: post.galleryImages,
          constrainAspectRatio: isCompact,
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
        final youtubeId = post.youtubeId;
        if (youtubeId != null && youtubeId.length >= 10) {
          return YoutubeVideoPlayer(youtubeId: youtubeId);
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
      if (!(post.url?.isNotEmpty ?? false) &&
          !(post.thumbnail?.isNotEmpty ?? false)) {
        return const SizedBox.shrink();
      }
      return ContentWidgets.cachedImage(
        context: context,
        imageUrl: post.imageUrl,
        aspectRatio: 16 / 9,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      );
    }

    if (!(post.url?.isNotEmpty ?? false)) return const SizedBox.shrink();
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
}
