import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/library_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory hiveRoot;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('library-offline-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    offlinePlaylistService.offlinePlaylists.value = [];
    userOfflineSongs.value = [];
    userCustomPlaylists.value = [
      {
        'ytid': 'customId-online',
        'title': 'Online only',
        'source': 'user-created',
      },
      {
        'ytid': 'customId-downloaded',
        'title': 'Downloaded mix',
        'source': 'user-created',
      },
    ];
  });
  tearDown(() async {
    await Hive.close();
    await hiveRoot.delete(recursive: true);
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: const LibraryPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'offline Library hides undownloaded root playlists and restores them online',
    (tester) async {
      offlinePlaylistService.offlinePlaylists.value = [
        {'ytid': 'customId-downloaded', 'title': 'Downloaded mix'},
      ];
      offlineMode.value = true;
      await pumpLibrary(tester);
      expect(find.text('Online only'), findsNothing);
      expect(find.text('Downloaded mix'), findsOneWidget);
      expect(userCustomPlaylists.value, hasLength(2));

      offlineMode.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Online only'), findsOneWidget);
      expect(find.text('Downloaded mix'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stored online library does not suppress the offline empty state',
    (tester) async {
      userPlaylistFolders.value = [
        {
          'id': 'online-folder',
          'name': 'Online folder',
          'playlists': [userCustomPlaylists.value.first],
        },
      ];
      userPlaylists.value = ['online-id'];
      offlineMode.value = true;
      await pumpLibrary(tester);
      expect(find.text('Offline mode'), findsOneWidget);
      expect(find.text('Online only'), findsNothing);
      expect(find.text('Online folder'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(userCustomPlaylists.value, hasLength(2));
      expect(userPlaylistFolders.value, hasLength(1));
    },
  );

  testWidgets(
    'offline Library keeps downloaded songs reachable without playlists',
    (tester) async {
      userCustomPlaylists.value = [];
      userOfflineSongs.value = [
        {
          'ytid': 'local-song',
          'title': 'Local tone',
          'audioPath': '/owned/fixture.wav',
        },
      ];
      offlineMode.value = true;
      await pumpLibrary(tester);
      expect(find.text('Offline songs'), findsOneWidget);
      expect(find.text('Offline mode'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
