import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import 'loading_widgets.dart';

class RedditVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const RedditVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<RedditVideoPlayer> createState() => _RedditVideoPlayerState();
}

class _RedditVideoPlayerState extends State<RedditVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(1.0);
      _controller = controller;

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return LoadingWidgets.videoError(context);
    if (!_isInitialized) return LoadingWidgets.videoLoading(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              if (!_controller!.value.isPlaying)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: AppConstants.videoOverlayOpacity),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
