import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/services/spotify_whole_source_readiness.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const service = SpotifyImportDestinationService();
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('whole-source-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  String uri(int row) => 'spotify:track:${row.toString().padLeft(22, 'a')}';
  List<Map<String, dynamic>> tracks() => [
    for (var row = 1; row <= 3; row++)
      {
        'sourceRow': row,
        'title': 'Owned source $row',
        'artist': 'Owned artist',
        'spotifyTrackUri': uri(row),
      },
  ];
  List<Map<String, dynamic>> results({bool duplicate = false}) => [
    for (final row in [2, 1, 3])
      {
        'sourceRow': row,
        'sourceTitle': 'Owned source $row',
        'sourceArtist': 'Owned artist',
        'status': row == 2 ? 'manually_matched' : 'matched',
        'bestCandidate': {
          'ytid': row == 2 || (duplicate && row == 3)
              ? 'chosen-alternative'
              : 'owned-$row',
          'title': 'Owned recording $row',
          'artist': 'Owner choice',
        },
      },
  ];
  Map<String, dynamic> source({bool unsupported = false}) =>
      SpotifySourcePlaylistCodec.encode([
        SpotifySourcePlaylist(
          position: 1,
          name: 'Owned source',
          spotifyUri: 'spotify:playlist:${''.padLeft(22, 'p')}',
          members: [
            SpotifyPlaylistMember(
              position: 1,
              sourceRow: 2,
              issue: null,
              sourceMetadata: {'uri': uri(2)},
            ),
            SpotifyPlaylistMember(
              position: 2,
              sourceRow: 1,
              issue: null,
              sourceMetadata: {'uri': uri(1)},
            ),
            SpotifyPlaylistMember(
              position: 3,
              sourceRow: 2,
              issue: null,
              sourceMetadata: {'uri': uri(2)},
            ),
            if (unsupported)
              const SpotifyPlaylistMember(
                position: 4,
                sourceRow: null,
                issue: 'unsupported item',
                sourceMetadata: {'title': 'Owned non-track'},
              ),
          ],
        ),
      ]);
  Future<void> seed({bool memberships = false, bool duplicate = false}) async {
    await Hive.box('user').putAll({
      'likedSongs': [
        {'ytid': 'keep-existing'},
      ],
      'customPlaylists': [
        {
          'ytid': 'customId-existing',
          'title': 'Existing',
          'source': 'user-created',
          'list': [
            {'ytid': 'keep-target'},
          ],
        },
      ],
      'spotifyImportTracks': tracks(),
      'spotifyMatchResults': results(duplicate: duplicate),
      'spotifyImportMetadata': {
        'importSessionId': 'whole-session',
        'fileName': 'owned.csv',
        'validTrackCount': 3,
        'totalDataRows': 3,
        'rejectedRowCount': 0,
        if (memberships) SpotifySourcePlaylistCodec.metadataKey: source(),
      },
    });
  }

  Future<SpotifyImportRouteResult> whole(
    SpotifyImportDestinationSnapshot snapshot, {
    SpotifyImportDestinationService using = service,
    SpotifyImportDestinationKind destination =
        SpotifyImportDestinationKind.likedSongs,
  }) => using.route(
    snapshot: snapshot,
    requestedCount: snapshot.resolvedSongs.length,
    destinationKind: destination,
    existingPlaylistId:
        destination == SpotifyImportDestinationKind.existingPlaylist
        ? 'customId-existing'
        : null,
    selectionKind: SpotifyImportSelectionKind.all,
    requireWholeSource: true,
  );
  List<String> liked() => (Hive.box('user').get('likedSongs') as List)
      .map((song) => (song as Map)['ytid'] as String)
      .toList();
  Future<void> status(String value) async {
    final changed = results();
    changed.singleWhere((result) => result['sourceRow'] == 3)['status'] = value;
    await Hive.box('user').put('spotifyMatchResults', changed);
  }

  test(
    'whole ready transfer preserves owner alternative, source order, existing content and repeat identity',
    () async {
      await seed();
      final beforeTracks = Hive.box('user').get('spotifyImportTracks');
      final snapshot = await service.loadSnapshot();
      expect(snapshot.wholeSourceReadiness!.ready, isTrue);
      expect(
        service
            .preview(
              snapshot: snapshot,
              requestedCount: 3,
              destinationKind: SpotifyImportDestinationKind.likedSongs,
              selectionKind: SpotifyImportSelectionKind.all,
              requireWholeSource: true,
            )
            .selectedCount,
        3,
      );
      expect((await whole(snapshot)).addedCount, 3);
      expect(liked(), [
        'owned-1',
        'chosen-alternative',
        'owned-3',
        'keep-existing',
      ]);
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      expect((await whole(await service.loadSnapshot())).addedCount, 0);
      expect(Hive.box('user').get('spotifyImportTracks'), beforeTracks);
      final metadata = Map<String, dynamic>.from(
        Hive.box('user').get('spotifyImportMetadata'),
      );
      expect(readImportRoutingBaseline(metadata, 'whole-session'), isNotNull);
      expect((metadata['routingHistory'] as List).last['selectionKind'], 'all');
    },
  );
  for (final state in ['excluded', 'unmatched', 'review', 'error']) {
    test(
      '$state blocks whole claim while explicit all-resolved retains partial workflow',
      () async {
        await seed();
        await status(state);
        final snapshot = await service.loadSnapshot();
        expect(snapshot.wholeSourceReadiness!.ready, isFalse);
        await expectLater(whole(snapshot), throwsStateError);
        expect(liked(), ['keep-existing']);
        final partial = await service.route(
          snapshot: snapshot,
          requestedCount: 3,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
          selectionKind: SpotifyImportSelectionKind.all,
        );
        expect(partial.selectedCount, 2);
        expect(
          (Hive.box('user').get('spotifyMatchResults') as List).singleWhere(
            (result) => result['sourceRow'] == 3,
          )['status'],
          state,
        );
      },
    );
  }
  test(
    'unsupported membership and rejected input counts block whole without rewriting source',
    () async {
      await seed(memberships: true);
      final metadata = Map<String, dynamic>.from(
        Hive.box('user').get('spotifyImportMetadata'),
      );
      metadata[SpotifySourcePlaylistCodec.metadataKey] = source(
        unsupported: true,
      );
      metadata['rejectedRowCount'] = 1;
      await Hive.box('user').put('spotifyImportMetadata', metadata);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.wholeSourceReadiness!.unsupported, 1);
      expect(snapshot.wholeSourceReadiness!.rejectedInputRows, 1);
      await expectLater(whole(snapshot), throwsStateError);
      expect(Hive.box('user').get('spotifyImportMetadata'), metadata);
      expect(
        service
            .selectSongs(
              snapshot,
              3,
              selectionKind: SpotifyImportSelectionKind.all,
            )
            .length,
        3,
      );
    },
  );
  test(
    'malformed legacy rows and count-only source remain unknown rather than complete',
    () async {
      await seed();
      for (final broken in [
        <dynamic>[...tracks(), 'damaged'],
        <dynamic>[...tracks(), tracks().first],
        <dynamic>[
          ...tracks().skip(1),
          {'sourceRow': '1', 'title': 'Legacy', 'artist': 'Owned'},
        ],
        <dynamic>[],
      ]) {
        await Hive.box('user').put('spotifyImportTracks', broken);
        final snapshot = await service.loadSnapshot();
        expect(snapshot.wholeSourceReadiness!.ready, isFalse);
        expect(snapshot.wholeSourceReadiness!.unknown, greaterThan(0));
        await expectLater(whole(snapshot), throwsStateError);
        expect(Hive.box('user').get('spotifyImportTracks'), broken);
      }
      final unknown = SpotifyWholeSourceReadiness.inspect(
        rawTracks: null,
        rawResults: null,
        metadata: {'fileName': 'legacy.csv', 'resolvedCount': 3},
      );
      expect(unknown.ready, isFalse);
      expect(unknown.unknown, greaterThan(0));
    },
  );
  test(
    'duplicate memberships stay retained while scoped whole selects unique recordings in member order',
    () async {
      await seed(memberships: true, duplicate: true);
      final before = Hive.box('user').get('spotifyImportMetadata');
      final snapshot = await service.loadSourcePlaylistSnapshot(1);
      expect(snapshot.wholeSourceReadiness!.ready, isTrue);
      expect(snapshot.wholeSourceReadiness!.repeatedMemberships, 1);
      expect((await whole(snapshot)).selectedCount, 2);
      expect(liked(), ['chosen-alternative', 'owned-1', 'keep-existing']);
      final current = Hive.box('user').get('spotifyImportMetadata');
      expect(
        current[SpotifySourcePlaylistCodec.metadataKey],
        before[SpotifySourcePlaylistCodec.metadataKey],
      );
    },
  );
  test(
    'readiness or source identity changing after preview rejects before any destination write',
    () async {
      await seed(memberships: true);
      final snapshot = await service.loadSourcePlaylistSnapshot(1);
      await status('excluded');
      await expectLater(whole(snapshot), throwsStateError);
      expect(liked(), ['keep-existing']);
      await Hive.box('user').put('spotifyMatchResults', results());
      final fresh = await service.loadSourcePlaylistSnapshot(1);
      final metadata = Map<String, dynamic>.from(
        Hive.box('user').get('spotifyImportMetadata'),
      );
      metadata['fileName'] = 'changed-source.json';
      await Hive.box('user').put('spotifyImportMetadata', metadata);
      await expectLater(whole(fresh), throwsStateError);
      expect(liked(), ['keep-existing']);
      expect(metadata.containsKey(importRoutingPendingKey), isFalse);
    },
  );
  test(
    'readiness loss during pending checkpoint preserves destination and newer owner exclusion',
    () async {
      await seed();
      var first = true;
      final guarded = SpotifyImportDestinationService(
        metadataWriter: (box, metadata) async {
          await box.put('spotifyImportMetadata', metadata);
          if (first) {
            first = false;
            await status('excluded');
          }
        },
      );
      await expectLater(
        whole(await service.loadSnapshot(), using: guarded),
        throwsStateError,
      );
      expect(liked(), ['keep-existing']);
      expect(
        (Hive.box('user').get('spotifyImportMetadata') as Map).containsKey(
          importRoutingPendingKey,
        ),
        isFalse,
      );
      expect((await service.loadSnapshot()).wholeSourceReadiness!.excluded, 1);
    },
  );
  test(
    'late destination callback retains actual writes and leaves tracking unverified across reopen',
    () async {
      await seed(memberships: true);
      final guarded = SpotifyImportDestinationService(
        destinationWriter: (box, key, value) async {
          await box.put(key, value);
          final metadata = Map<String, dynamic>.from(
            box.get('spotifyImportMetadata'),
          );
          metadata[SpotifySourcePlaylistCodec.metadataKey] = source(
            unsupported: true,
          );
          await box.put('spotifyImportMetadata', metadata);
        },
      );
      final result = await whole(await service.loadSnapshot(), using: guarded);
      expect(result.trackingRecorded, isFalse);
      expect(liked(), [
        'owned-1',
        'chosen-alternative',
        'owned-3',
        'keep-existing',
      ]);
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      final metadata = Map<String, dynamic>.from(
        Hive.box('user').get('spotifyImportMetadata'),
      );
      expect(metadata[importRoutingPendingKey], isNotNull);
      expect(readImportRoutingBaseline(metadata, 'whole-session'), isNull);
      expect(
        (await service.loadSnapshot()).wholeSourceReadiness!.unsupported,
        1,
      );
    },
  );
  test(
    'whole retry preserves existing playlist prefix and snapshot survives saved-file restore/reopen',
    () async {
      await seed();
      final snapshot = await service.loadSnapshot();
      expect(
        (await whole(
          snapshot,
          destination: SpotifyImportDestinationKind.existingPlaylist,
        )).addedCount,
        3,
      );
      expect(
        (await whole(
          await service.loadSnapshot(),
          destination: SpotifyImportDestinationKind.existingPlaylist,
        )).addedCount,
        0,
      );
      final playlists = Hive.box('user').get('customPlaylists');
      expect(playlists.single['list'].first['ytid'], 'keep-target');
      final payloads = <String, Uint8List>{};
      for (final name in ['user', 'settings']) {
        final box = Hive.box(name);
        await box.flush();
        payloads[name] = await File(box.path!).readAsBytes();
      }
      final saved =
          await MusifyBackupService.createStreamedBundleFileForTesting(
            payloads,
            root,
          );
      final inspected = await MusifyBackupService.inspectBundleFileForTesting(
        saved,
      );
      expect(
        (await MusifyBackupService.restoreValidatedBackup(inspected)).success,
        isTrue,
      );
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      expect(
        (await service.loadSnapshot()).wholeSourceReadiness!.ready,
        isTrue,
      );
      expect(Hive.box('user').get('customPlaylists'), playlists);
    },
  );
  test(
    'declared source row mismatch and lost named membership cannot imply whole completeness',
    () async {
      await seed();
      final metadata = Map<String, dynamic>.from(
        Hive.box('user').get('spotifyImportMetadata'),
      );
      metadata['validTrackCount'] = 4;
      await Hive.box('user').put('spotifyImportMetadata', metadata);
      expect(
        (await service.loadSnapshot()).wholeSourceReadiness!.ready,
        isFalse,
      );
      metadata['validTrackCount'] = 3;
      metadata['format'] = 'Named Spotify playlist backup';
      await Hive.box('user').put('spotifyImportMetadata', metadata);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.wholeSourceReadiness!.unknown, greaterThan(0));
      await expectLater(whole(snapshot), throwsStateError);
      expect(liked(), ['keep-existing']);
    },
  );
  test(
    'whole readiness verification rejects oversize and deeply malformed legacy structures safely',
    () {
      final tooMany = SpotifyWholeSourceReadiness.inspect(
        rawTracks: List.filled(10001, null),
        rawResults: const [],
        metadata: {'importSessionId': 'owned'},
      );
      expect(tooMany.ready, isFalse);
      expect(tooMany.fingerprint, isNull);
      expect(tooMany.issue, contains('10000'));
      Object? deep = 'owned';
      for (var i = 0; i < 70; i++) {
        deep = [deep];
      }
      final raw = results();
      raw.first['bestCandidate'] = Map<String, dynamic>.from(
        raw.first['bestCandidate'] as Map,
      )..['ownedLegacyField'] = deep;
      final unknown = SpotifyWholeSourceReadiness.inspect(
        rawTracks: tracks(),
        rawResults: raw,
        metadata: {'importSessionId': 'owned'},
      );
      expect(unknown.ready, isFalse);
      expect(unknown.unknown, greaterThan(0));
      expect(unknown.fingerprint, isNull);
    },
  );
  test(
    'new permanent-exclusion index after preview is live even before its matched outcome checkpoint changes',
    () async {
      await seed();
      final snapshot = await service.loadSnapshot();
      final original = Hive.box('user').get('spotifyMatchResults');
      await Hive.box('user').put('spotifyExcludedImportRows', ['3']);
      await expectLater(whole(snapshot), throwsStateError);
      expect(liked(), ['keep-existing']);
      final current = await service.loadSnapshot();
      expect(current.wholeSourceReadiness!.excluded, 1);
      expect(current.resolvedSongs.map((song) => song['ytid']), [
        'owned-1',
        'chosen-alternative',
      ]);
      expect(Hive.box('user').get('spotifyMatchResults'), original);
      expect(Hive.box('user').get('spotifyExcludedImportRows'), ['3']);
    },
  );
  test(
    'malformed exclusion index blocks writes while retaining its unknown legacy value',
    () async {
      await seed();
      await Hive.box(
        'user',
      ).put('spotifyExcludedImportRows', {'legacy': 'unknown'});
      final snapshot = await service.loadSnapshot();
      expect(snapshot.wholeSourceReadiness!.ready, isFalse);
      await expectLater(
        service.route(
          snapshot: snapshot,
          requestedCount: 3,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
          selectionKind: SpotifyImportSelectionKind.all,
        ),
        throwsStateError,
      );
      expect(liked(), ['keep-existing']);
      expect(Hive.box('user').get('spotifyExcludedImportRows'), {
        'legacy': 'unknown',
      });
    },
  );
  test(
    'newer destination edits remain stored and visible after the owned callback',
    () async {
      await seed();
      final guarded = SpotifyImportDestinationService(
        destinationWriter: (box, key, value) async {
          await box.put(key, value);
          await box.put(key, [
            ...value,
            {'ytid': 'keep-newer'},
          ]);
        },
      );
      expect(
        (await whole(
          await service.loadSnapshot(),
          using: guarded,
        )).trackingRecorded,
        isTrue,
      );
      expect(liked(), [
        'owned-1',
        'chosen-alternative',
        'owned-3',
        'keep-existing',
        'keep-newer',
      ]);
      expect(userLikedSongsList.value, Hive.box('user').get('likedSongs'));
    },
  );
}
