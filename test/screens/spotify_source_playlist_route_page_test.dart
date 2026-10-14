import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/screens/spotify_source_playlists_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_song_list_importer.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import '../support/spotify_playlist_fixture.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-route-page-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await const SpotifyImportSessionService().saveNewImport(
      SpotifySongListImporter.parseBytes(
        SpotifyPlaylistFixture.bytes(),
        fileName: 'account.json',
      ),
    );
    final box = Hive.box('user');
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    final first = SpotifySourcePlaylistCodec.decode(
      metadata['sourcePlaylists'],
    ).first;
    metadata['sourcePlaylists'] = SpotifySourcePlaylistCodec.encode([
      first,
      SpotifySourcePlaylist(
        position: 2,
        name: 'Two',
        spotifyUri: null,
        members: [
          SpotifyPlaylistMember(
            position: 1,
            sourceRow: 4,
            issue: null,
            sourceMetadata: {'uri': 'spotify:track:${'B' * 22}'},
          ),
          SpotifyPlaylistMember(
            position: 2,
            sourceRow: 1,
            issue: null,
            sourceMetadata: {'uri': 'spotify:track:${'A' * 22}'},
          ),
          const SpotifyPlaylistMember(
            position: 3,
            sourceRow: null,
            issue: 'Unavailable',
          ),
        ],
      ),
    ]);
    await box.putAll({
      'spotifyImportMetadata': metadata,
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'manually_matched',
          'bestCandidate': {'ytid': 'chosen-A', 'title': 'Selected A'},
        },
        {
          'sourceRow': 4,
          'status': 'matched',
          'bestCandidate': {'ytid': 'chosen-B', 'title': 'Selected B'},
        },
      ],
      'likedSongs': [
        {'ytid': 'keep', 'title': 'Keep'},
      ],
    });
    userLikedSongsList.value = List.from(box.get('likedSongs'));
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  testWidgets(
    'source review routes only after explicit ordered preview and confirm; cancel and retry are safe',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        priorityReviewApp(
          child: const SpotifySourcePlaylistsPage(
            routingService: _IoDestinationService(),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Two').last);
      await tester.pumpAndSettle();
      final before = jsonDecode(jsonEncode(Hive.box('user').toMap()));
      await tester.tap(find.text('Route resolved songs'));
      await tester.pumpAndSettle();
      expect(find.text('Source playlist: Two'), findsOneWidget);
      expect(Hive.box('user').toMap(), before);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<SpotifyImportConfirmationDialog>(
        find.byType(SpotifyImportConfirmationDialog),
      );
      expect(dialog.preview.selectedSongs.map((s) => s['ytid']), [
        'chosen-B',
        'chosen-A',
      ]);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(Hive.box('user').toMap(), before);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transfer songs'));
      await tester.pump();
      var finished = false;
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final history =
            Hive.box('user').get('spotifyImportMetadata')['routingHistory']
                as List? ??
            [];
        if (history.isNotEmpty &&
            find.text('Review').evaluate().length == 1 &&
            find.byType(SpotifyImportConfirmationDialog).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          finished = true;
          break;
        }
      }
      expect(finished, isTrue);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        (Hive.box('user').get('likedSongs') as List).map((s) => s['ytid']),
        ['chosen-B', 'chosen-A', 'keep'],
      );
      expect(
        Hive.box('user').get('spotifyImportMetadata')['sourcePlaylists'],
        (before as Map)['spotifyImportMetadata']['sourcePlaylists'],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

// Keep real Hive serialized writes outside Flutter's per-test fake-clock zone.
class _IoDestinationService extends SpotifyImportDestinationService {
  const _IoDestinationService();
  @override
  Future<SpotifyImportRouteResult> route({
    required SpotifyImportDestinationSnapshot snapshot,
    required int requestedCount,
    required SpotifyImportDestinationKind destinationKind,
    String? newPlaylistName,
    String? existingPlaylistId,
    SpotifyImportSelectionKind selectionKind =
        SpotifyImportSelectionKind.firstCount,
    Set<String> selectedRecordingIds = const {},
    bool requireWholeSource = false,
  }) {
    final completed = Completer<SpotifyImportRouteResult>();
    Zone.root.run(
      () => super
          .route(
            snapshot: snapshot,
            requestedCount: requestedCount,
            destinationKind: destinationKind,
            newPlaylistName: newPlaylistName,
            existingPlaylistId: existingPlaylistId,
            selectionKind: selectionKind,
            selectedRecordingIds: selectedRecordingIds,
            requireWholeSource: requireWholeSource,
          )
          .then<void>(
            completed.complete,
            onError: (Object error, StackTrace stack) =>
                completed.completeError(error, stack),
          ),
    );
    return completed.future;
  }
}
