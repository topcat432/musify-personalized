import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart' show shuffleNotifier;

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory hiveRoot;
  late _CaptureQueueHandler handler;

  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('playlist-page-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    shuffleNotifier.value = false;
    handler = _CaptureQueueHandler();
    audioHandler = handler;
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    await handler.audioPlayer.dispose();
    await Hive.close();
    await hiveRoot.delete(recursive: true);
  });

  testWidgets(
    'an unavailable playlist renders its error inside a scroll view',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        priorityReviewApp(
          brightness: Brightness.dark,
          child: const MediaQuery(
            data: MediaQueryData(size: Size(360, 640)),
            child: PlaylistPage(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text('An error occurred. Check logs or try again.'),
        findsOneWidget,
      );
      expect(find.byType(CustomScrollView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'playlist Shuffle requests real shuffle with natural source order',
    (tester) async {
      await tester.pumpWidget(
        priorityReviewApp(
          brightness: Brightness.dark,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: PlaylistPage(
              playlistData: {
                'ytid': 'customId-shuffle-regression',
                'title': 'Ordered playlist',
                'source': 'user-created',
                'image': '',
                'list': [
                  for (final id in ['first', 'second', 'third'])
                    {'ytid': id, 'title': id, 'artist': 'Fixture artist'},
                ],
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Shuffle');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(handler.shuffle, isTrue);
      expect(handler.replace, isTrue);
      expect(handler.startIndex, 0);
      expect(handler.songs.map((song) => song['ytid']), [
        'first',
        'second',
        'third',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final query in ['match', 'SECOND', '']) {
    testWidgets('playlist search preserves repeated slot for "$query"', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(800, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repeated = {
        'ytid': 'repeated',
        'title': 'Match repeated',
        'artist': 'Fixture',
      };
      final songs = [
        {'ytid': 'prefix', 'title': 'Hidden prefix', 'artist': 'Fixture'},
        repeated,
        {'ytid': 'middle', 'title': 'Hidden middle', 'artist': 'Fixture'},
        repeated,
        {
          'ytid': 'repeated',
          'title': 'Match second version',
          'artist': 'Fixture',
        },
      ];
      await tester.pumpWidget(
        priorityReviewApp(
          brightness: Brightness.dark,
          child: PlaylistPage(
            playlistData: {
              'ytid': 'customId-repeat-search',
              'title': 'Repeated playlist',
              'source': 'user-created',
              'image': '',
              'list': songs,
            },
          ),
        ),
      );
      await tester.pump();
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, query);
      await tester.pump();
      final target = query == 'match'
          ? find.text('Match repeated').last
          : find.text('Match second version');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
      expect(handler.startIndex, query == 'match' ? 3 : 4);
      expect(handler.replace, isTrue);
      expect(
        handler.songs.map((song) => song['title']),
        songs.map((song) => song['title']),
      );
      expect(
        handler.songs[handler.startIndex!]['title'],
        query == 'match' ? 'Match repeated' : 'Match second version',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _CaptureQueueHandler extends MusifyAudioHandler {
  List<Map> songs = [];
  bool replace = false;
  bool shuffle = false;
  int? startIndex;

  @override
  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
    bool shuffle = false,
  }) async {
    this.songs = List<Map>.from(songs);
    this.replace = replace;
    this.shuffle = shuffle;
    this.startIndex = startIndex;
  }
}
