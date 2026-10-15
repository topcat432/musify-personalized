import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/playlist_folder_page.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/widgets/dialog_item.dart';

import '../../tool/visual_review_harness.dart';

dynamic _copy(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is List) return value.map(_copy).toList();
  if (value is Map) return value.map((key, item) => MapEntry(key, _copy(item)));
  return value;
}

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('owned-source-picker-');
    Hive.init(root.path); await initPriorityReviewHive(); resetPriorityReviewGlobals();
  });
  tearDown(() async { await Hive.close(); await root.delete(recursive: true); });

  for (final change in ['changed', 'deleted', 'ambiguous']) {
    testWidgets('retained folder picker preserves current source: $change', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String, dynamic>{
        'ytid': 'customId-picker', 'title': 'Owned picker playlist',
        'source': 'user-created', 'list': [{'ytid': 'owned-a', 'title': 'Old member'}],
        'bytes': Uint8List.fromList([1, 2]),
      };
      final lookup = Completer<List<dynamic>>();
      Future<void> persist() => Hive.box('user').putAll({
        'customPlaylists': userCustomPlaylists.value,
        'playlistFolders': userPlaylistFolders.value,
        'playlists': userPlaylists.value,
      });
      await tester.runAsync(() async {
        userCustomPlaylists.value = [selected];
        userPlaylistFolders.value = [{'id': 'target', 'name': 'Target', 'playlists': <Map>[]}];
        await persist(); await Hive.box('user').put('ownedUnrelated', {'keep': true});
      });
      await tester.pumpWidget(priorityReviewApp(brightness: Brightness.light,
        child: PlaylistFolderPage(folderId: 'target', folderName: 'Target',
          youtubePlaylistLoader: () => lookup.future)));
      await tester.pumpAndSettle();
      tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>)).onSelected!('add');
      await tester.pump();
      await tester.runAsync(() async {
        if (change == 'changed') {
          userCustomPlaylists.value = [{...selected, 'title': 'Newer owner playlist',
            'list': [{'ytid': 'owned-new', 'title': 'Newer owner member'}],
            'bytes': Uint8List.fromList([9, 8]), 'ownerAt': DateTime.utc(2026, 1, 1)}];
        } else if (change == 'deleted') {
          userCustomPlaylists.value = [];
        } else {
          userPlaylistFolders.value = [
            ...userPlaylistFolders.value,
            {'id': 'other', 'name': 'Other owner', 'playlists': [{...selected, 'owner': 'retain-other'}]},
          ];
        }
        await persist(); await Hive.box('user').flush();
      });
      lookup.complete([]);
      await tester.pumpAndSettle();
      late Map expected;
      late List<int> expectedBytes;
      await tester.runAsync(() async {
        expected = _copy(Hive.box('user').toMap()) as Map;
        expectedBytes = await File('${root.path}/user.hive').readAsBytes();
      });
      final card = tester.widget<DialogItem>(find.widgetWithText(DialogItem, 'Owned picker playlist'));
      Zone.root.run(card.onTap);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero); await Hive.box('user').flush();
        expect(Hive.box('user').toMap(), expected, reason: 'PICKER_OVERWROTE_CURRENT_SOURCE');
        expect(await File('${root.path}/user.hive').readAsBytes(), expectedBytes);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Hive.close(); Hive.init(root.path); await initPriorityReviewHive();
        expect(Hive.box('user').toMap(), expected);
      });
    }, timeout: const Timeout(Duration(seconds: 25)));
  }
}
