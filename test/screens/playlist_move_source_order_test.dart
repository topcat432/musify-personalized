import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart' show playlistSortSetting, shuffleNotifier;
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/sort_chips.dart';

import '../../tool/visual_review_harness.dart';

dynamic _copy(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is List) return value.map(_copy).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key, _copy(item)));
  return value;
}

void main() {
  late Directory root;
  late MusifyAudioHandler handler;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-sort-move-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
    playlistSortSetting = 'default_';
    shuffleNotifier.value = false;
    handler = MusifyAudioHandler(); audioHandler = handler;
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    await handler.audioPlayer.dispose(); await Hive.close(); await root.delete(recursive: true);
  });

  for (final mode in [PlaylistSortType.title, PlaylistSortType.artist, PlaylistSortType.dateAdded]) {
    for (final folder in [false, true]) {
      testWidgets('widget sort then move retains canonical source order: ${mode.name} folder=$folder', (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repeated = {'ytid': 'same-recording', 'title': 'Zulu', 'artist': 'A', 'version': 'shared'};
        final playlist = <String, dynamic>{
          'ytid': 'customId-source-order', 'title': 'Owned source order',
          'source': 'user-created', 'image': '',
          'bytes': Uint8List.fromList([1, 2]), 'at': DateTime.utc(2026, 1, 1),
          'list': [repeated, {'ytid': 'bridge', 'title': 'Bridge', 'artist': 'Z'},
            {'ytid': 'same-recording', 'title': 'Alpha', 'artist': 'Y', 'version': 'selected'},
            {'ytid': 'tail', 'title': 'Tail', 'artist': 'B'}, repeated],
        };
        final expected = _copy(playlist) as Map;
        final other = {'ytid': 'customId-other', 'title': 'Other', 'source': 'user-created', 'list': <Map>[]};
        await tester.runAsync(() async {
          userCustomPlaylists.value = [if (!folder) playlist, other];
          userPlaylistFolders.value = [
            if (folder) {'id': 'source', 'name': 'Source', 'playlists': [playlist]},
            {'id': 'target', 'name': 'Target', 'playlists': <Map>[]},
          ];
          userLikedPlaylists.value = [_copy(playlist) as Map];
          pinnedPlaylistIds.value = ['customId-source-order'];
          await Hive.box('user').putAll({
            'customPlaylists': userCustomPlaylists.value,
            'playlistFolders': userPlaylistFolders.value,
            'playlists': userPlaylists.value,
            'likedPlaylists': userLikedPlaylists.value,
            'pinnedPlaylistIds': pinnedPlaylistIds.value,
          });
        });
        late BuildContext libraryContext;
        await tester.pumpWidget(priorityReviewAppSized(brightness: Brightness.dark, viewSize: const Size(800, 1800),
          child: Builder(builder: (context) {
            libraryContext = context;
            return TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PlaylistPage(playlistId: 'customId-source-order'))),
              child: const Text('Open owned playlist'));
          })));
        await tester.tap(find.text('Open owned playlist')); await tester.pumpAndSettle();
        final chips = tester.widget<SortChips<PlaylistSortType>>(find.byType(SortChips<PlaylistSortType>));
        Zone.root.run(() => chips.onSelected(mode)); await tester.pump();
        final displayed = tester.widgetList<SongBar>(find.byType(SongBar)).map((row) => row.song['title']);
        expect(displayed, switch (mode) {
          PlaylistSortType.title => ['Alpha', 'Bridge', 'Tail', 'Zulu', 'Zulu'],
          PlaylistSortType.artist => ['Zulu', 'Zulu', 'Tail', 'Alpha', 'Bridge'],
          _ => ['Zulu', 'Tail', 'Alpha', 'Bridge', 'Zulu'],
        });
        final back = tester.widget<IconButton>(find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'Back'));
        Zone.root.run(back.onPressed!); await tester.pumpAndSettle();
        expect(find.text('Open owned playlist'), findsOneWidget);
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero); await Hive.box('settings').flush();
          final current = getUserCustomPlaylists().singleWhere((p) => p['ytid'] == 'customId-source-order');
          final beforeMove = _copy(current);
          expect(await movePlaylistToFolder(current, 'target', libraryContext), '${libraryContext.l10n!.addedSuccess}!');
          await Hive.box('user').flush();
          await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
          final target = (Hive.box('user').get('playlistFolders') as List).singleWhere((f) => f['id'] == 'target');
          final saved = (target['playlists'] as List).single as Map;
          expect(saved['list'], expected['list'], reason: 'MOVE_PERSISTED_DISPLAY_SORT_AS_SOURCE');
          expect(beforeMove, expected);
          expect(saved, expected);
          expect(saved['bytes'], isA<Uint8List>());
          expect((saved['at'] as DateTime).isUtc, isTrue);
          expect((Hive.box('user').get('customPlaylists') as List).single, other);
          expect(Hive.box('user').get('likedPlaylists'), [expected]);
          expect(Hive.box('user').get('pinnedPlaylistIds'), ['customId-source-order']);
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }, timeout: const Timeout(Duration(seconds: 25)));
    }
  }
}
