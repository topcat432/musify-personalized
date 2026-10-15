import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart'
    show shuffleNotifier, playlistSortSetting;
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/rename_song_dialog.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory root;
  late MusifyAudioHandler handler;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('playlist-rename-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    shuffleNotifier.value = false;
    playlistSortSetting = 'default_';
    handler = MusifyAudioHandler();
    audioHandler = handler;
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    await handler.audioPlayer.dispose();
    await Hive.close();
    await root.delete(recursive: true);
  });

  for (final folder in [false, true]) {
    for (final mode in PlaylistSortType.values) {
      testWidgets('rename only the selected shared repeated row in ${mode.name}, filtered, folder=$folder', (tester) async {
        try {
          tester.view
            ..physicalSize = const Size(800, 1600)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          playlistSortSetting = mode.name;
          final shared = {'ytid': 'repeat', 'title': 'Shared', 'artist': 'R', 'version': 'chosen'};
          final alternative = {'ytid': 'repeat', 'title': 'Alternative', 'artist': 'A', 'version': 'other'};
          final playlist = <String, dynamic>{
            'ytid': 'customId-rename', 'title': 'Rename fixture',
            'source': 'user-created', 'image': '',
            'list': [shared, alternative, {'ytid': 'bridge', 'title': 'Bridge', 'artist': 'B'}, shared],
            'legacy': {'keep': true},
          };
          final key = folder ? 'playlistFolders' : 'customPlaylists';
          final other = {'ytid': 'customId-other', 'source': 'user-created', 'title': 'Other', 'list': <Map>[]};
          final collection = folder
              ? <Map>[{'id': 'folder', 'name': 'Owned folder', 'playlists': [playlist, other]}]
              : <Map>[playlist, other];
          if (folder) { userPlaylistFolders.value = collection; }
          else { userCustomPlaylists.value = collection; }
          Future<void> drain() => tester.runAsync(() => Zone.root.run(() async {
            await Future<void>.delayed(Duration.zero);
            if (Hive.isBoxOpen('user')) await Hive.box('user').flush();
            if (Hive.isBoxOpen('settings')) await Hive.box('settings').flush();
            await Future<void>.delayed(Duration.zero);
          }));
          await tester.runAsync(() => Zone.root.run(() => Hive.box('user').put(key, collection)));
          await tester.pumpWidget(priorityReviewApp(brightness: Brightness.dark, child: PlaylistPage(playlistData: playlist)));
          await tester.pump();
          await tester.enterText(find.byType(TextField), 'Shared');
          await tester.pump();
          final row = find.byType(SongBar).last;
          final menu = tester.widget<OverflowMenuButton<String>>(find.descendant(of: row, matching: find.byType(OverflowMenuButton<String>)));
          menu.onSelected('rename');
          await tester.pump(const Duration(milliseconds: 300));
          final fields = find.descendant(of: find.byType(RenameSongDialog), matching: find.byType(TextField));
          await tester.enterText(fields.at(0), 'Renamed');
          await tester.enterText(fields.at(1), 'New artist');
          final confirm = tester.widget<FilledButton>(find.descendant(of: find.byType(RenameSongDialog), matching: find.byType(FilledButton)));
          Zone.root.run(confirm.onPressed!);
          Zone.root.run(confirm.onPressed!); // Repeat must not pop the page.
          await tester.pump(const Duration(milliseconds: 300));
          await drain();
          await tester.pump();
          Map current() => folder
              ? (userPlaylistFolders.value.single['playlists'] as List).first
              : userCustomPlaylists.value.first;
          final songs = current()['list'] as List;
          expect(songs.where((s) => s['title'] == 'Renamed'), hasLength(1));
          expect(songs.where((s) => s['title'] == 'Shared'), hasLength(1));
          expect(shared['title'], 'Shared');
          expect(alternative['title'], 'Alternative');
          expect(songs.singleWhere((s) => s['title'] == 'Renamed')['version'], 'chosen');
          expect(songs.singleWhere((s) => s['title'] == 'Renamed')['artist'], 'New artist');
          expect(find.byType(SongBar), findsOneWidget);
          await tester.enterText(find.byType(TextField), '');
          await tester.pump();
          final expected = mode == PlaylistSortType.dateAdded
              ? ['Renamed', 'Alternative', 'Bridge', 'Shared']
              : ['Shared', 'Alternative', 'Bridge', 'Renamed'];
          for (final sort in [PlaylistSortType.default_, PlaylistSortType.dateAdded, PlaylistSortType.default_]) {
            final chips = tester.widget<SortChips<PlaylistSortType>>(find.byType(SortChips<PlaylistSortType>));
            Zone.root.run(() => chips.onSelected(sort));
            await tester.pump();
            await drain();
            expect((current()['list'] as List).map((s) => s['title']), sort == PlaylistSortType.dateAdded ? expected.reversed : expected);
          }
          expect(current()['legacy'], {'keep': true});
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 11));
          await drain();
          await tester.runAsync(() => Zone.root.run(() async { await Hive.close(); Hive.init(root.path); await initPriorityReviewHive(); }));
          final stored = Hive.box('user').get(key) as List;
          final children = folder ? stored.single['playlists'] as List : stored;
          expect((children.first['list'] as List).map((s) => s['title']), expected);
          expect(children.last, other);
          expect((children.first as Map).keys.toSet(), playlist.keys.toSet());
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 11));
          await tester.runAsync(() => Zone.root.run(() async {
            await Future<void>.delayed(Duration.zero);
            if (Hive.isBoxOpen('user')) await Hive.box('user').flush();
            if (Hive.isBoxOpen('settings')) await Hive.box('settings').flush();
          }));
        }
      }, timeout: const Timeout(Duration(seconds: 25)));
    }
  }
  for (final folder in [false, true]) {
    for (final cancel in [false, true]) {
      testWidgets('rename dialog preserves cancel or changed source: folder=$folder cancel=$cancel', (tester) async {
        try {
          tester.view
            ..physicalSize = const Size(800, 1600)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final first = {'ytid': 'same', 'title': 'First', 'artist': 'Artist'};
          final selected = {'ytid': 'same', 'title': 'Selected', 'artist': 'Artist'};
          final playlist = <String, dynamic>{'ytid': 'customId-dialog', 'source': 'user-created', 'title': 'Dialog fixture', 'image': '', 'list': [first, selected]};
          final key = folder ? 'playlistFolders' : 'customPlaylists';
          final collection = folder ? <Map>[{'id': 'folder', 'name': 'Folder', 'playlists': [playlist]}] : <Map>[playlist];
          if (folder) { userPlaylistFolders.value = collection; }
          else { userCustomPlaylists.value = collection; }
          await tester.runAsync(() => Zone.root.run(() async { await Hive.box('user').put(key, collection); await Hive.box('user').flush(); }));
          final before = await tester.runAsync(() => File('${root.path}/user.hive').readAsBytes());
          await tester.pumpWidget(priorityReviewApp(brightness: Brightness.dark, child: PlaylistPage(playlistData: playlist)));
          await tester.pump();
          final menu = tester.widget<OverflowMenuButton<String>>(find.descendant(of: find.byType(SongBar).last, matching: find.byType(OverflowMenuButton<String>)));
          menu.onSelected('rename');
          await tester.pump(const Duration(milliseconds: 300));
          if (cancel) {
            await tester.tap(find.descendant(of: find.byType(RenameSongDialog), matching: find.byType(OutlinedButton)));
          } else {
            playlist['list'] = [first, {...selected, 'title': 'Owner pending'}];
            final fields = find.descendant(of: find.byType(RenameSongDialog), matching: find.byType(TextField));
            await tester.enterText(fields.at(0), 'Wrong replacement');
            final confirm = tester.widget<FilledButton>(find.descendant(of: find.byType(RenameSongDialog), matching: find.byType(FilledButton)));
          Zone.root.run(confirm.onPressed!);
          }
          await tester.pump(const Duration(milliseconds: 300));
          await tester.runAsync(() => Zone.root.run(() async { await Future<void>.delayed(Duration.zero); await Hive.box('user').flush(); }));
          expect((playlist['list'] as List).map((s) => s['title']), ['First', cancel ? 'Selected' : 'Owner pending']);
          final after = await tester.runAsync(() => File('${root.path}/user.hive').readAsBytes());
          expect(after, before);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 11));
          await tester.runAsync(() => Zone.root.run(() async {
            await Future<void>.delayed(Duration.zero);
            if (Hive.isBoxOpen('user')) await Hive.box('user').flush();
            if (Hive.isBoxOpen('settings')) await Hive.box('settings').flush();
          }));
        }
      }, timeout: const Timeout(Duration(seconds: 25)));
    }
  }
}
