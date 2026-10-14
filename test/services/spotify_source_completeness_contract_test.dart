import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const service = SpotifyImportDestinationService();
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-contract-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await Hive.box('user').putAll({
      'spotifyImportMetadata': {
        'importSessionId': 'contract',
        'fileName': 'owned.csv',
        'validTrackCount': 1,
        'rejectedRowCount': 0,
        'totalDataRows': 1,
      },
      'spotifyImportTracks': [
        {
          'sourceRow': 1,
          'title': 'Owned',
          'artist': 'Owned',
          'spotifyTrackUri': 'spotify:track:aaaaaaaaaaaaaaaaaaaaaa',
        },
      ],
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'matched',
          'bestCandidate': {'ytid': 'owned', 'title': 'Owned'},
        },
      ],
    });
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  Future<void> metadata(Map<String, dynamic> values) async =>
      Hive.box('user').put('spotifyImportMetadata', values);
  Map<String, dynamic> current() =>
      Map<String, dynamic>.from(Hive.box('user').get('spotifyImportMetadata'));
  Future<void> reopen() async {
    await Hive.close();
    Hive.init(root.path);
    await Hive.openBox('user');
    await Hive.openBox('settings');
  }

  Future<SpotifyImportRouteResult> route(
    SpotifyImportDestinationSnapshot snapshot, {
    SpotifyImportDestinationService using = service,
    bool whole = false,
    SpotifyImportDestinationKind kind = SpotifyImportDestinationKind.likedSongs,
  }) => using.route(
    snapshot: snapshot,
    requestedCount: 1,
    destinationKind: kind,
    selectionKind: SpotifyImportSelectionKind.all,
    requireWholeSource: whole,
    newPlaylistName: 'Owned new',
  );

  test(
    'declared total must equal retained flat rows plus rejected rows',
    () async {
      await metadata(current()..['totalDataRows'] = 2);
      expect(
        (await service.loadSnapshot()).wholeSourceReadiness!.ready,
        isFalse,
        reason: 'Inconsistent declared total must not certify whole source',
      );
      expect((await route(await service.loadSnapshot())).addedCount, 1);
    },
  );
  test(
    'missing or malformed total cannot certify legacy completeness',
    () async {
      final base = current();
      for (final value in [null, -1, 1.0, '1', true, 0, 2]) {
        await metadata({...base, 'totalDataRows': value});
        expect(
          (await service.loadSnapshot()).wholeSourceReadiness!.ready,
          isFalse,
        );
      }
      await metadata(Map<String, dynamic>.from(base)..remove('totalDataRows'));
      expect(
        (await service.loadSnapshot()).wholeSourceReadiness!.ready,
        isFalse,
      );
      expect((await route(await service.loadSnapshot())).addedCount, 1);
    },
  );
  test(
    'total-only change after preview rejects commit and preserves source',
    () async {
      final snapshot = await service.loadSnapshot();
      expect(snapshot.wholeSourceReadiness!.ready, isTrue);
      service.preview(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.all,
        requireWholeSource: true,
      );
      await metadata(current()..['totalDataRows'] = 2);
      await expectLater(route(snapshot, whole: true), throwsStateError);
      expect(Hive.box('user').get('likedSongs', defaultValue: []), isEmpty);
      await reopen();
      expect(current()['totalDataRows'], 2);
    },
  );
  test(
    'named total counts all memberships including repeats and unsupported entries',
    () async {
      final sources = SpotifySourcePlaylistCodec.encode([
        SpotifySourcePlaylist(
          position: 1,
          name: 'Owned repeats',
          spotifyUri: null,
          members: [
            for (final position in [1, 2])
              SpotifyPlaylistMember(
                position: position,
                sourceRow: 1,
                issue: null,
                sourceMetadata: const {
                  'uri': 'spotify:track:aaaaaaaaaaaaaaaaaaaaaa',
                },
              ),
          ],
        ),
        const SpotifySourcePlaylist(
          position: 2,
          name: 'Owned unsupported',
          spotifyUri: null,
          members: [
            SpotifyPlaylistMember(
              position: 1,
              sourceRow: null,
              issue: 'unsupported',
              sourceMetadata: {'title': 'Owned unsupported'},
            ),
          ],
        ),
      ]);
      await metadata({
        ...current(),
        'format': 'Named Spotify playlist backup',
        'sourcePlaylists': sources,
        'rejectedRowCount': 1,
        'totalDataRows': 3,
      });
      final scoped = await service.loadSourcePlaylistSnapshot(1);
      expect(scoped.wholeSourceReadiness!.ready, isTrue);
      expect(scoped.wholeSourceReadiness!.repeatedMemberships, 1);
      expect(
        (await service.loadSourcePlaylistSnapshot(
          2,
        )).wholeSourceReadiness!.unsupported,
        1,
      );
      await metadata(current()..['totalDataRows'] = 2);
      expect(
        (await service.loadSourcePlaylistSnapshot(
          1,
        )).wholeSourceReadiness!.ready,
        isFalse,
      );
    },
  );
  test(
    'deleted likes with stale cache stay deleted after transfer and reopen',
    () async {
      userLikedSongsList.value = [
        {'ytid': 'deleted-like'},
      ];
      await Hive.box('user').delete('likedSongs');
      await route(await service.loadSnapshot());
      expect(
        (Hive.box('user').get('likedSongs') as List).map((s) => s['ytid']),
        ['owned'],
        reason: 'Deleted stored likes must never resurrect from stale cache',
      );
      await reopen();
      expect(
        (Hive.box('user').get('likedSongs') as List).map((s) => s['ytid']),
        ['owned'],
      );
    },
  );
  test(
    'deletion during pending metadata callback never resurrects stale likes',
    () async {
      userLikedSongsList.value = [
        {'ytid': 'deleted-like'},
      ];
      await Hive.box('user').put('likedSongs', userLikedSongsList.value);
      final guarded = SpotifyImportDestinationService(
        metadataWriter: (box, value) async {
          await box.put('spotifyImportMetadata', value);
          await box.delete('likedSongs');
        },
      );
      await route(await service.loadSnapshot(), using: guarded);
      // The callback also deletes the final destination: absence remains authoritative.
      expect(Hive.box('user').containsKey('likedSongs'), isFalse);
      await reopen();
      expect(Hive.box('user').containsKey('likedSongs'), isFalse);
      final normal = await route(await service.loadSnapshot());
      expect(normal.addedCount, 1);
      expect(
        (Hive.box('user').get('likedSongs') as List).map((s) => s['ytid']),
        ['owned'],
      );
    },
  );
  test(
    'missing playlist and folder collections never revive stale destinations',
    () async {
      final deleted = {
        'ytid': 'customId-deleted',
        'title': 'Deleted',
        'source': 'user-created',
        'list': [
          {'ytid': 'deleted-song'},
        ],
      };
      userCustomPlaylists.value = [deleted];
      userPlaylistFolders.value = [
        {
          'id': 'deleted-folder',
          'playlists': [deleted],
        },
      ];
      await Hive.box('user').deleteAll(['customPlaylists', 'playlistFolders']);
      expect(
        (await service.loadSnapshot()).customPlaylists,
        isEmpty,
        reason:
            'Deleted playlist collections must never resurrect from stale cache',
      );
      await route(
        await service.loadSnapshot(),
        kind: SpotifyImportDestinationKind.newPlaylist,
      );
      await reopen();
      final saved = Hive.box('user').get('customPlaylists') as List;
      expect(saved.length, 1);
      expect(saved.single['title'], 'Owned new');
      expect(Hive.box('user').containsKey('playlistFolders'), isFalse);
    },
  );
  test(
    'pending deletion of existing destination fails closed without restoring cache',
    () async {
      final deleted = {
        'ytid': 'customId-deleted',
        'title': 'Deleted',
        'source': 'user-created',
        'list': [],
      };
      await Hive.box('user').put('customPlaylists', [deleted]);
      userCustomPlaylists.value = [deleted];
      final snapshot = await service.loadSnapshot();
      final guarded = SpotifyImportDestinationService(
        metadataWriter: (box, value) async {
          await box.put('spotifyImportMetadata', value);
          await box.delete('customPlaylists');
        },
      );
      await expectLater(
        guarded.route(
          snapshot: snapshot,
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.existingPlaylist,
          existingPlaylistId: 'customId-deleted',
          selectionKind: SpotifyImportSelectionKind.all,
        ),
        throwsStateError,
      );
      await reopen();
      expect(Hive.box('user').containsKey('customPlaylists'), isFalse);
      expect((await service.loadSnapshot()).customPlaylists, isEmpty);
    },
  );
}
