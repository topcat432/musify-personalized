import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/mini_player.dart';
import '../../tool/visual_review_harness.dart';

class _GestureHandler extends MusifyAudioHandler {
  @override
  Stream<PositionData> get positionDataStream => Stream.value(
    PositionData(Duration.zero, Duration.zero, const Duration(seconds: 70)),
  );
  @override
  Stream<PlaybackState> get playbackStateStream => playbackState;
}

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('mini-gesture-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    offlineMode.value = true;
    final handler = _GestureHandler();
    audioHandler = handler;
    const item = MediaItem(
      id: 'owned-gesture',
      title: 'Owned',
      artist: 'Fixture',
      duration: Duration(seconds: 70),
    );
    handler.mediaItem.add(item);
    handler.queue.add([item]);
    handler.playbackState.add(
      PlaybackState(
        processingState: AudioProcessingState.ready,
        playing: false,
      ),
    );
    addTearDown(() async {
      await handler.stop();
      await handler.audioPlayer.dispose();
    });
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  testWidgets(
    'slow upward drag opens once and single Back permits a new gesture',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _RouteObserver();
      final wrapper = priorityMiniPlayerScreen(Brightness.light) as MediaQuery;
      final base = wrapper.child as MaterialApp;
      await tester.pumpWidget(
        MaterialApp(
          theme: base.theme,
          locale: base.locale,
          localizationsDelegates: base.localizationsDelegates,
          supportedLocales: base.supportedLocales,
          home: base.home,
          navigatorObservers: [observer],
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      final mini = find.byType(MiniPlayer);
      expect(mini, findsOneWidget);
      expect(tester.getSize(mini).height, greaterThan(60));
      final start = tester.getTopLeft(mini) + const Offset(35, 36);
      observer.pushes = 0;
      final down = await tester.startGesture(start);
      for (var i = 0; i < 30; i++) {
        await down.moveBy(const Offset(0, 2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await down.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(observer.pushes, 0);
      final up = await tester.startGesture(start);
      for (var i = 0; i < 30; i++) {
        await up.moveBy(const Offset(0, -2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await up.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 1);
      expect(find.byType(NowPlayingPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NowPlayingPage), findsNothing);
      final second = await tester.startGesture(start);
      for (var i = 0; i < 30; i++) {
        await second.moveBy(const Offset(0, -2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await second.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(observer.pushes, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
