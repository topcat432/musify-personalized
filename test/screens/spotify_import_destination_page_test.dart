import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/common_services.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SpotifyImportDestinationSnapshot snapshot;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('destination-page-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    final songs = [
      for (var row = 1; row <= 3; row++)
        {'ytid': 'fixture-$row', 'title': 'Fixture $row'},
    ];
    await Hive.box('user').putAll({
      'spotifyImportMetadata': {
        'importSessionId': 'fixture-session',
        'fileName': 'fixture.csv',
      },
      'spotifyImportTracks': [
        for (var row = 1; row <= 3; row++) {'sourceRow': row},
      ],
      'spotifyMatchResults': [
        for (var row = 1; row <= 3; row++)
          {
            'sourceRow': row,
            'status': 'matched',
            'bestCandidate': songs[row - 1],
          },
      ],
    });
    snapshot = SpotifyImportDestinationSnapshot(
      importSessionId: 'fixture-session',
      sourceName: 'fixture',
      resolvedSongs: songs,
      resolvedResultCount: 3,
      unresolvedCount: 0,
      customPlaylists: const [],
    );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  testWidgets(
    'first-N stays selected after transfer and a repeat remains idempotent',
    (tester) async {
      await tester.pumpWidget(
        priorityReviewApp(
          child: SpotifyImportDestinationPage(initialSnapshot: snapshot),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      final exactAmount = find.text('Choose an exact amount');
      await tester.scrollUntilVisible(exactAmount, 300);
      await tester.tap(exactAmount);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Review'));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Transfer songs'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await Hive.box('user').flush();
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1',
      );
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'fixture-1',
      ]);
      await tester.runAsync(() async {
        await tester.tap(find.text('Review'));
      });
      await tester.pumpAndSettle();
      final dialog = tester.widget<SpotifyImportConfirmationDialog>(
        find.byType(SpotifyImportConfirmationDialog),
      );
      expect(dialog.preview.selectedCount, 1);
      expect(dialog.preview.newCount, 0);
      expect(dialog.preview.alreadyPresentCount, 1);
      await tester.runAsync(() async {
        await tester.tap(find.text('Transfer songs'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await Hive.box('user').flush();
      });
      await tester.pumpAndSettle();
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'fixture-1',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
