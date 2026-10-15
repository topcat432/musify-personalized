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

  for (final mode in PlaylistSortType.values) {
    for (final folder in [false, true]) {
      for (final sharedRemoval in [
        false,
        if (mode == PlaylistSortType.title) true,
      ]) {
        testWidgets(
          'Undo one repeated slot in ${mode.name}, filtered, folder=$folder shared=$sharedRemoval',
          (tester) async {
            try {
              tester.view
                ..physicalSize = const Size(800, 1600)
                ..devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              playlistSortSetting = mode.name;
              final shared = {'ytid': 'repeat', 'title': 'Zulu', 'artist': 'Z'};
              final original = [
                shared,
                {'ytid': 'repeat', 'title': 'Alpha', 'artist': 'T'},
                {'ytid': 'bridge', 'title': 'Bridge', 'artist': 'B'},
                {'ytid': 'tail', 'title': 'Tail', 'artist': 'A'},
                shared,
              ];
              final playlist = <String, dynamic>{
                'ytid': 'customId-undo-repeat',
                'title': 'Undo fixture',
                'source': 'user-created',
                'image': '',
                'list': List.from(original),
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
              Future<void> drain() => tester.runAsync(
                () => Zone.root.run(() async {
                  await Future<void>.delayed(Duration.zero);
                  await Hive.box('settings').flush();
                  await Hive.box('user').flush();
                  await Future<void>.delayed(Duration.zero);
                }),
              );
              await tester.runAsync(
                () => Zone.root.run(() async {
                  await Hive.box('user').put(key, collection);
                  await Hive.box(
                    'user',
                  ).put('unrelatedFixture', {'keep': true});
                }),
              );
              await tester.pumpWidget(
                priorityReviewApp(
                  brightness: Brightness.dark,
                  child: PlaylistPage(playlistData: playlist),
                ),
              );
              await tester.pump();
              final row = tester
                  .widgetList<SongBar>(find.byType(SongBar))
                  .where(
                    (r) =>
                        r.song['title'] == (sharedRemoval ? 'Zulu' : 'Alpha'),
                  )
                  .last;
              Zone.root.run(row.onRemove!);
              await tester.pump();
              await drain();
              final action = tester.widget<SnackBarAction>(
                find.byType(SnackBarAction),
              );
              Future<void> sort(PlaylistSortType type) async {
                final chips = tester.widget<SortChips<PlaylistSortType>>(
                  find.byType(SortChips<PlaylistSortType>),
                );
                Zone.root.run(() => chips.onSelected(type));
                await tester.pump();
                await drain();
              }

              final undoSort = switch (mode) {
                PlaylistSortType.default_ => PlaylistSortType.dateAdded,
                PlaylistSortType.dateAdded => PlaylistSortType.default_,
                PlaylistSortType.title => PlaylistSortType.artist,
                PlaylistSortType.artist => PlaylistSortType.title,
              };
              await sort(undoSort);
              await tester.enterText(find.byType(TextField), 'Zulu');
              await tester.pump();
              expect(
                tester
                    .widgetList<SongBar>(find.byType(SongBar))
                    .every((r) => r.onRemove == null),
                isTrue,
              );
              Zone.root.run(action.onPressed);
              Zone.root.run(
                action.onPressed,
              ); // overlapping repeat must be harmless
              await drain();
              await tester.pump();
              Map current() => folder
                  ? (userPlaylistFolders.value.single['playlists'] as List)
                        .single
                  : userCustomPlaylists.value.single;
              final savedTitles = (current()['list'] as List)
                  .map((song) => song['title'])
                  .toList();
              final sourceTitles = original
                  .map((song) => song['title'])
                  .toList();
              expect(
                savedTitles,
                undoSort == PlaylistSortType.dateAdded
                    ? sourceTitles.reversed
                    : undoSort == PlaylistSortType.default_
                    ? sourceTitles
                    : (List<dynamic>.from(original)..sort(
                            (a, b) =>
                                (a[undoSort == PlaylistSortType.title
                                            ? 'title'
                                            : 'artist']
                                        as String)
                                    .compareTo(
                                      b[undoSort == PlaylistSortType.title
                                              ? 'title'
                                              : 'artist']
                                          as String,
                                    ),
                          ))
                          .map((song) => song['title']),
              );
              expect(
                tester
                    .widgetList<SongBar>(find.byType(SongBar))
                    .where((row) => row.song['title'] == 'Zulu'),
                hasLength(2),
              );
              await tester.enterText(find.byType(TextField), '');
              await tester.pump();
              for (final type in [
                PlaylistSortType.default_,
                PlaylistSortType.dateAdded,
                PlaylistSortType.default_,
              ]) {
                await sort(type);
                expect(
                  (current()['list'] as List).map((song) => song['title']),
                  type == PlaylistSortType.dateAdded
                      ? sourceTitles.reversed
                      : sourceTitles,
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
              // Let the shared artwork cache perform its owned 10-second cleanup.
              await tester.pump(const Duration(seconds: 11));
              await drain();
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
              expect(Hive.box('user').get('unrelatedFixture'), {'keep': true});
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 11));
              await tester.runAsync(
                () => Zone.root.run(() async {
                  await Future<void>.delayed(Duration.zero);
                  if (Hive.isBoxOpen('user')) await Hive.box('user').flush();
                  if (Hive.isBoxOpen('settings'))
                    await Hive.box('settings').flush();
                }),
              );
            }
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
