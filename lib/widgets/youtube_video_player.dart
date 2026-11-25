import 'package:material_ui/material_ui.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme/app_theme.dart';

class YoutubeVideoPlayer extends StatefulWidget {
  final String youtubeId;

  const YoutubeVideoPlayer({
    super.key,
    required this.youtubeId,
  });

  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeId,
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: YoutubePlayer(controller: _controller),
    );
  }
}
