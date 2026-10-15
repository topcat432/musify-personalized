import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart'
    show shuffleNotifier, playlistSortSetting;
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';

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
    playlistSortSetting = 'default_';
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
  for (final mode in PlaylistSortType.values) {
    for (final folder in [
      false,
      if (mode == PlaylistSortType.dateAdded) true,
    ]) {
      for (final shared in [
        false,
        if (mode == PlaylistSortType.default_ && !folder) true,
      ]) {
        testWidgets(
          'one repeated slot survives sort cycles and reopen: ${mode.name} folder=$folder shared=$shared',
          (tester) async {
            tester.view
              ..physicalSize = const Size(800, 1600)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            playlistSortSetting = mode.name;
            final repeated = {'ytid': 'repeat', 'title': 'Zulu', 'artist': 'Z'};
            final playlist = <String, dynamic>{
              'ytid': 'customId-remove-repeat',
              'title': 'Repeated slots',
              'source': 'user-created',
              'image': '',
              'list': [
                repeated,
                {'ytid': 'bridge', 'title': 'Bridge', 'artist': 'B'},
                {'ytid': 'repeat', 'title': 'Alpha', 'artist': 'A'},
                {'ytid': 'tail', 'title': 'Tail', 'artist': 'T'},
                repeated,
              ],
            };
            final key = folder ? 'playlistFolders' : 'customPlaylists';
            final collection = folder
                ? <Map>[
                    {
                      'id': 'folder',
                      'name': 'Fixture folder',
                      'playlists': [playlist],
                    },
                  ]
                : <Map>[playlist];
            if (folder) {
              userPlaylistFolders.value = collection;
            } else {
              userCustomPlaylists.value = collection;
            }
            await tester.runAsync(
              () => Zone.root.run(() async {
                await Hive.box('user').put(key, collection);
                await Hive.box('user').put('unrelatedFixture', {'keep': true});
              }),
            );
            await tester.pumpWidget(
              priorityReviewApp(
                brightness: Brightness.dark,
                child: PlaylistPage(playlistData: playlist),
              ),
            );
            await tester.pump();
            final removeRow = tester
                .widgetList<SongBar>(find.byType(SongBar))
                .where(
                  (row) => row.song['title'] == (shared ? 'Zulu' : 'Alpha'),
                )
                .last;
            Zone.root.run(removeRow.onRemove!);
            await tester.pump();
            final savedTitles = (playlist['list'] as List)
                .map((song) => song['title'])
                .toList();
            expect(
              savedTitles.where((title) => title == 'Zulu').length,
              shared ? 1 : 2,
            );
            expect(savedTitles.contains('Alpha'), shared);
            await tester.runAsync(
              () => Zone.root.run(() => Hive.box('user').flush()),
            );
            Future<void> sort(PlaylistSortType type) async {
              final chips = tester.widget<SortChips<PlaylistSortType>>(
                find.byType(SortChips<PlaylistSortType>),
              );
              final chip = find.widgetWithText(
                FilterChip,
                chips.sortTypeToString(type),
              );
              await tester.ensureVisible(chip);
              // The production callback owns real Hive writes; keep them outside
              // Flutter's fake-clock zone, like the existing source-route fixtures.
              Zone.root.run(() => chips.onSelected(type));
              await tester.pump();
              await tester.runAsync(
                () => Zone.root.run(() async {
                  // Drain the callback's open-box continuation before flush/close.
                  await Future<void>.delayed(Duration.zero);
                  await Hive.box('settings').flush();
                  await Hive.box('user').flush();
                }),
              );
            }

            for (final type in [
              PlaylistSortType.default_,
              PlaylistSortType.dateAdded,
              PlaylistSortType.default_,
            ]) {
              await sort(type);
              final expected = shared
                  ? ['Zulu', 'Bridge', 'Alpha', 'Tail']
                  : ['Zulu', 'Bridge', 'Tail', 'Zulu'];
              expect(
                tester.widgetList<SongBar>(find.byType(SongBar)).map((row) => row.song['title']),
                type == PlaylistSortType.dateAdded ? expected.reversed : expected,
              );
              expect(
                (playlist['list'] as List).map((song) => song['title']),
                expected,
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(
              () => Zone.root.run(() async {
                await Hive.close();
                Hive.init(hiveRoot.path);
                await initPriorityReviewHive();
              }),
            );
            final storedCollection = Hive.box('user').get(key) as List;
            final stored = folder
                ? (storedCollection.single['playlists'] as List).single
                : storedCollection.single;
            expect(
              (stored['list'] as List).map((song) => song['title']),
              savedTitles,
            );
            expect((stored as Map).keys.toSet(), {
              'ytid',
              'title',
              'source',
              'image',
              'list',
            });
            expect(
              (stored['list'] as List).every(
                (song) => (song as Map).keys.toSet().difference({
                  'ytid',
                  'title',
                  'artist',
                }).isEmpty,
              ),
              isTrue,
            );
            expect(Hive.box('user').get('unrelatedFixture'), {'keep': true});
            expect(tester.takeException(), isNull);
          },
          timeout: const Timeout(Duration(seconds: 25)),
        );
      }
    }
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
