import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../constants/app_constants.dart';
import 'loading_widgets.dart';

class RedditVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const RedditVideoPlayer({super.key, required this.videoUrl});

  @override
  State<RedditVideoPlayer> createState() => _RedditVideoPlayerState();
}

class _RedditVideoPlayerState extends State<RedditVideoPlayer> {
  /// How long controls remain visible after last interaction during playback.
  static const _kHideControlsAfter = Duration(milliseconds: 2200);

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

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
      if (mounted) setState(() => _isInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
      _controlsVisible = true;
    });
    _scheduleHide();
  }

  /// While playing, fade controls after [_kHideControlsAfter]. While paused,
  /// keep them visible so the user can always scrub.
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _hideTimer = Timer(_kHideControlsAfter, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return LoadingWidgets.videoError(context);
    if (!_isInitialized) return LoadingWidgets.videoLoading(context);

    final controller = _controller!;
    final colors = ThemeHelper(context);
    final isPlaying = controller.value.isPlaying;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: VideoPlayer(controller),
            ),
            if (!isPlaying)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: AppConstants.videoOverlayOpacity,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _VideoProgressBar(
                    controller: controller,
                    accent: colors.accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  final VideoPlayerController controller;
  final Color accent;

  const _VideoProgressBar({required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: AppConstants.videoOverlayOpacity),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      child: Row(
        children: [
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: VideoProgressColors(
                playedColor: accent,
                bufferedColor: Colors.white.withValues(alpha: 0.4),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing2),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Text(
                '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}
