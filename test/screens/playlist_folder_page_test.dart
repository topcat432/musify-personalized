import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/playlist_folder_page.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory hiveRoot;

  setUpAll(() {
    initPriorityReviewTestPlugins();
  });

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('playlist-folder-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    offlinePlaylistService.offlinePlaylists.value = [];
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  Map<String, dynamic> playlist(String id, String title) => {
    'ytid': id,
    'title': title,
    'source': 'user-created',
    'image': null,
  };

  void seedFolder(String folderId, String folderName, List<Map> playlists) {
    userPlaylistFolders.value = [
      {
        'id': folderId,
        'name': folderName,
        'playlists': playlists,
        'createdAt': 0,
      },
    ];
  }

  Future<void> pumpFolder(
    WidgetTester tester, {
    required String folderId,
    required String folderName,
  }) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: PlaylistFolderPage(folderId: folderId, folderName: folderName),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a populated folder with its playlists', (tester) async {
    seedFolder('folder-1', 'Road Trip', [
      playlist('p1', 'Midnight Drive'),
      playlist('p2', 'Golden Hour'),
    ]);

    await pumpFolder(tester, folderId: 'folder-1', folderName: 'Road Trip');

    expect(find.text('Road Trip'), findsOneWidget);
    expect(find.text('2 playlists'), findsOneWidget);
    expect(find.text('Midnight Drive'), findsOneWidget);
    expect(find.text('Golden Hour'), findsOneWidget);
  });

  testWidgets('renders the empty state when the folder has no playlists', (
    tester,
  ) async {
    seedFolder('folder-1', 'Road Trip', []);

    await pumpFolder(tester, folderId: 'folder-1', folderName: 'Road Trip');

    expect(
      find.text('This folder is empty. Add playlists to organize your music.'),
      findsOneWidget,
    );
  });

  testWidgets('offline mode shows only downloaded playlists', (tester) async {
    seedFolder('folder-1', 'Road Trip', [
      playlist('p1', 'Midnight Drive'),
      playlist('p2', 'Golden Hour'),
    ]);
    offlinePlaylistService.offlinePlaylists.value = [
      {'ytid': 'p1', 'title': 'Midnight Drive'},
    ];
    offlineMode.value = true;

    await pumpFolder(tester, folderId: 'folder-1', folderName: 'Road Trip');

    expect(find.text('Midnight Drive'), findsOneWidget);
    expect(find.text('Golden Hour'), findsNothing);
    expect(find.text('1 playlist'), findsOneWidget);
  });

  testWidgets('the rename dialog opens pre-filled with the current name', (
    tester,
  ) async {
    seedFolder('folder-1', 'Road Trip', [playlist('p1', 'Midnight Drive')]);

    await pumpFolder(tester, folderId: 'folder-1', folderName: 'Road Trip');

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit folder'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text ?? field.initialValue, 'Road Trip');

    // Cancelling must not mutate anything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(userPlaylistFolders.value.single['name'], 'Road Trip');
    expect(find.text('Road Trip'), findsOneWidget);
  });

  test('renamePlaylistFolder updates the folder name in storage', () async {
    // Exercises the same service call the rename dialog's "Update" button
    // makes (`_showRenameFolderDialog`), without going through the dialog's
    // UI/showToast/audioHandler path, which needs heavier audio-service
    // fixtures than this visual-only screen otherwise depends on.
    seedFolder('folder-1', 'Road Trip', [playlist('p1', 'Midnight Drive')]);

    final result = renamePlaylistFolder('folder-1', 'Weekend Mix');

    expect(result, 'Folder updated successfully');
    expect(userPlaylistFolders.value.single['name'], 'Weekend Mix');
  });
}
