import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const review = SpotifyReviewWorkflowService();
  const destination = SpotifyImportDestinationService();

  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('import-persistence-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> reopen() async {
    await Hive.close();
    await initPriorityReviewHive();
    reloadPlaylistLibraryStateFromStorage();
    userLikedSongsList.value = List.from(
      Hive.box('user').get('likedSongs', defaultValue: []),
    );
  }

  test(
    'alternate decisions and every destination retain identity across reopen',
    () async {
      final originalTracks = [
        for (var row = 1; row <= 5; row++)
          {
            'sourceRow': row,
            'title': 'Imported $row',
            'artist': 'Fixture artist',
          },
      ];
      final alternate = <String, dynamic>{
        'candidate': {
          'ytid': 'chosen-alternate',
          'title': 'Selected recording',
          'artist': 'Fixture artist',
        },
        'score': 0.84,
        'evidence': {'titleScore': 0.9, 'primaryArtistScore': 0.9},
      };
      final existing = <String, dynamic>{
        'ytid': 'existing-folder-playlist',
        'title': 'Existing playlist',
        'source': 'user-created',
        'list': [
          {'ytid': 'keep-existing', 'title': 'Keep'},
        ],
      };
      final box = Hive.box('user');
      await box.putAll({
        'spotifyImportTracks': originalTracks,
        'spotifyImportMetadata': {
          'importSessionId': 'fixture-session',
          'fileName': 'fixture.csv',
        },
        // Deliberately not in source order; destination loading must restore it.
        'spotifyMatchResults': [
          {
            'sourceRow': 2,
            'sourceTitle': 'Imported 2',
            'status': 'matched',
            'bestCandidate': {
              'ytid': 'second-source',
              'title': 'Second recording',
            },
          },
          {
            'sourceRow': 1,
            'sourceTitle': 'Imported 1',
            'status': 'needs_review',
            'alternatives': [
              {
                'candidate': {
                  'ytid': 'rejected-top',
                  'title': 'Wrong recording',
                },
                'score': 0.95,
              },
              alternate,
            ],
          },
          {'sourceRow': 3, 'sourceTitle': 'Imported 3', 'status': 'unmatched'},
          {
            'sourceRow': 4,
            'sourceTitle': 'Imported 4',
            'status': 'error',
            'error': 'Synthetic unavailable metadata',
          },
          {
            'sourceRow': 5,
            'sourceTitle': 'Imported 5',
            'status': 'manual_unmatched',
          },
        ],
        'likedSongs': [
          {'ytid': 'keep-liked', 'title': 'Keep liked'},
        ],
        'playlistFolders': [
          {
            'id': 'fixture-folder',
            'name': 'Fixture folder',
            'playlists': [existing],
          },
        ],
      });
      reloadPlaylistLibraryStateFromStorage();
      userLikedSongsList.value = List.from(box.get('likedSongs'));
      var pending = await review.loadUnresolvedItems();
      await review.resolveItem(
        item: pending.singleWhere((item) => item['sourceRow'] == 1),
        accept: true,
        selectedAlternative: alternate,
      );
      await review.resolveItem(
        item: pending.singleWhere((item) => item['sourceRow'] == 3),
        accept: false,
      );
      await review.excludeItem(
        item: pending.singleWhere((item) => item['sourceRow'] == 5),
      );
      final snapshot = await destination.loadSnapshot();
      expect(snapshot.resolvedSongs.map((song) => song['ytid']), [
        'chosen-alternate',
        'second-source',
      ]);
      expect(snapshot.unresolvedCount, 2);
      expect(snapshot.resolvedResultCount, 2);
      var result = await destination.route(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(result.addedCount, 1);
      result = await destination.route(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(result.addedCount, 0);
      expect(result.alreadyPresentCount, 1);
      await destination.route(
        snapshot: snapshot,
        requestedCount: 2,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      await destination.route(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Fixture routed',
      );
      await destination.route(
        snapshot: snapshot,
        requestedCount: 2,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Fixture routed',
      );
      result = await destination.route(
        snapshot: snapshot,
        requestedCount: 2,
        destinationKind: SpotifyImportDestinationKind.existingPlaylist,
        existingPlaylistId: 'existing-folder-playlist',
      );
      expect(result.addedCount, 2);
      await reopen();
      final restored = Hive.box('user');
      expect(restored.get('spotifyImportTracks'), originalTracks);
      expect(
        (restored.get('likedSongs') as List).map(
          (song) => (song as Map)['ytid'],
        ),
        ['second-source', 'chosen-alternate', 'keep-liked'],
      );
      expect(userCustomPlaylists.value, hasLength(1));
      expect(
        (userCustomPlaylists.value.single['list'] as List).map(
          (song) => (song as Map)['ytid'],
        ),
        ['chosen-alternate', 'second-source'],
      );
      final folderPlaylist =
          (userPlaylistFolders.value.single['playlists'] as List).single as Map;
      expect(
        (folderPlaylist['list'] as List).map((song) => (song as Map)['ytid']),
        ['keep-existing', 'chosen-alternate', 'second-source'],
      );
      pending = await review.loadUnresolvedItems();
      expect(pending.map((item) => item['sourceRow']).toSet(), {3, 4});
      expect(
        pending.singleWhere((item) => item['sourceRow'] == 3)['status'],
        'manual_unmatched',
      );
      expect(restored.get('spotifyExcludedImportRows'), ['5']);
      final savedResults = restored.get('spotifyMatchResults') as List;
      final accepted = savedResults.cast<Map>().singleWhere(
        (item) => item['sourceRow'] == 1,
      );
      expect((accepted['bestCandidate'] as Map)['ytid'], 'chosen-alternate');
      final metadata = restored.get('spotifyImportMetadata') as Map;
      expect(metadata['routingHistory'], hasLength(6));
      result = await destination.route(
        snapshot: await destination.loadSnapshot(),
        requestedCount: 2,
        destinationKind: SpotifyImportDestinationKind.existingPlaylist,
        existingPlaylistId: 'existing-folder-playlist',
      );
      expect(result.addedCount, 0);
      expect(result.alreadyPresentCount, 2);
    },
  );

  test(
    'empty, missing destination, and stale routing reject without mutation',
    () async {
      final box = Hive.box('user');
      await box.putAll({
        'spotifyImportMetadata': {'importSessionId': 'current'},
        'spotifyImportTracks': [
          {'sourceRow': 1},
        ],
        'spotifyMatchResults': [
          {
            'sourceRow': 1,
            'status': 'matched',
            'bestCandidate': {'ytid': 'fixture'},
          },
        ],
        'likedSongs': [
          {'ytid': 'keep'},
        ],
      });
      userLikedSongsList.value = List.from(box.get('likedSongs'));
      final snapshot = await destination.loadSnapshot();
      final before = jsonEncode({
        for (final key in box.keys) key.toString(): box.get(key),
      });
      await expectLater(
        destination.route(
          snapshot: snapshot,
          requestedCount: 0,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
        ),
        throwsStateError,
      );
      await expectLater(
        destination.route(
          snapshot: snapshot,
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.existingPlaylist,
          existingPlaylistId: 'missing',
        ),
        throwsStateError,
      );
      expect(
        jsonEncode({for (final key in box.keys) key.toString(): box.get(key)}),
        before,
      );
      await box.put('spotifyImportMetadata', {
        'importSessionId': 'replacement',
      });
      final replacementBefore = jsonEncode({
        for (final key in box.keys) key.toString(): box.get(key),
      });
      await expectLater(
        destination.route(
          snapshot: snapshot,
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
        ),
        throwsStateError,
      );
      expect(
        jsonEncode({for (final key in box.keys) key.toString(): box.get(key)}),
        replacementBefore,
      );
      await reopen();
      expect(
        jsonEncode({
          for (final key in Hive.box('user').keys)
            key.toString(): Hive.box('user').get(key),
        }),
        replacementBefore,
      );
    },
  );
}
