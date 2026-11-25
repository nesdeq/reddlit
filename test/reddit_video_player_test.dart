import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:reddlit/widgets/reddit_video_player.dart';

class _FakeVideoPlatform extends VideoPlayerPlatform {
  final created = <int>[];
  final disposed = <int>[];
  final events = <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = created.length;
    created.add(id);
    events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late _FakeVideoPlatform platform;

  setUp(() {
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<void> showPlayer(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RedditVideoPlayer(videoUrl: 'https://v.redd.it/x/HLSPlaylist.m3u8'),
      ),
    ));
    await tester.pump();
    expect(platform.created, hasLength(1));
  }

  // VideoPlayerController.dispose reaches the platform only on real event-loop
  // turns, which fake-async pumps do not drive.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(pumpEventQueue);
  }

  Future<void> removePlayer(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets('removed while initializing: the platform player is released',
      (tester) async {
    await showPlayer(tester);
    await removePlayer(tester);
    expect(platform.disposed, platform.created);
  });

  testWidgets('failed initialization: error shown and the player is released',
      (tester) async {
    await showPlayer(tester);
    platform.events[0]!
        .addError(PlatformException(code: 'source', message: 'unreachable'));
    await settle(tester);
    await tester.pump();
    expect(find.text('Failed to load video'), findsOneWidget);
    expect(platform.disposed, platform.created);
    await removePlayer(tester);
    expect(platform.disposed, platform.created);
  });

  testWidgets('initialized player is released exactly once on removal',
      (tester) async {
    await showPlayer(tester);
    platform.events[0]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 1),
      size: const Size(16, 9),
    ));
    await tester.pump();
    expect(find.text('Failed to load video'), findsNothing);
    await removePlayer(tester);
    expect(platform.disposed, platform.created);
  });
}
