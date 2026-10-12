import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_track_matching_service.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const service = SpotifyImportDestinationService();
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('i11-routing-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });
  tearDown(() async {
    await Hive.close();
    final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final fixtureRoot = await root.resolveSymbolicLinks();
    if (!fixtureRoot.startsWith(
      '$temporaryRoot${Platform.pathSeparator}i11-routing-',
    )) {
      throw StateError('Refusing cleanup outside the owned fixture');
    }
    await root.delete(recursive: true);
  });

  Map<String, dynamic> recording(int row, {String? id}) => {
    'ytid': id ?? (row == 2 ? 'chosen-alternate-2' : 'recording-$row'),
    'title': 'Owned recording $row',
    'artist': 'Owned artist',
    'duration': 180,
    'album': 'Owned album',
    'sourceType': 'youtube_music_song',
  };
  Future<void> seed({bool legacy = false}) async {
    await Hive.box('settings').putAll({
      'themeIndex': 2,
      'offlineMode': false,
      'wrappedEnabled': false,
      'fixtureSettings': 'preserved',
    });
    await Hive.box('user').putAll({
      'likedSongs': [
        {'ytid': 'keep-like', 'title': 'Keep existing'},
      ],
      'customPlaylists': [
        {
          'ytid': 'customId-existing',
          'title': 'Existing',
          'source': 'user-created',
          'list': [
            {'ytid': 'keep-playlist'},
          ],
        },
      ],
      'playlistFolders': [
        {
          'id': 'folder',
          'title': 'Folder',
          'playlists': [
            {
              'ytid': 'customId-folder',
              'title': 'Folder target',
              'source': 'user-created',
              'list': [
                {'ytid': 'keep-folder'},
              ],
            },
          ],
        },
      ],
      'spotifyImportTracks': [
        for (var row = 1; row <= 4; row++)
          {
            'sourceRow': row,
            'title': 'Owned source $row',
            'artist': 'Owned artist',
          },
      ],
      'spotifyMatchResults': [
        for (var row = 1; row <= 4; row++)
          {
            'sourceRow': row,
            'sourceTitle': 'Owned source $row',
            'sourceArtist': 'Owned artist',
            'status': row == 4 ? 'unmatched' : 'matched',
            if (row != 4) 'bestCandidate': recording(row),
          },
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'i11-session',
        'fileName': 'owned.csv',
        'matchingStatus': 'complete',
        'nextTrackIndex': 4,
        'customPreserved': {'date': DateTime.utc(2026, 1, 2)},
        if (!legacy)
          importRoutingBaselineKey: importRoutingBaseline(
            sessionId: 'i11-session',
            rows: const [],
            recordedAt: '2026-01-02T00:00:00Z',
            reliable: true,
            reason: 'import_start',
          ),
        if (legacy)
          'routingHistory': [
            {
              'selectedCount': 1,
              'routedAt': '2026-01-01',
              'typedDate': DateTime.utc(2026, 1, 1),
            },
          ],
      },
    });
    reloadPlaylistLibraryStateFromStorage();
    userLikedSongsList.value = List.from(Hive.box('user').get('likedSongs'));
  }

  Future<void> reopen() async {
    await Hive.close();
    await initPriorityReviewHive();
    reloadPlaylistLibraryStateFromStorage();
    userLikedSongsList.value = List.from(Hive.box('user').get('likedSongs'));
  }

  Map<String, dynamic> metadata() => Map<String, dynamic>.from(
    Hive.box('user').get('spotifyImportMetadata') as Map,
  );

  for (final target in ['liked', 'new', 'existing', 'folder']) {
    test(
      'individual $target routing keeps alternatives, source order, old contents and reopen',
      () async {
        await seed();
        final snapshot = await service.loadSnapshot();
        final originalResults = copyImportRoutingValue(
          Hive.box('user').get('spotifyMatchResults'),
        );
        final kind = target == 'liked'
            ? SpotifyImportDestinationKind.likedSongs
            : target == 'new'
            ? SpotifyImportDestinationKind.newPlaylist
            : SpotifyImportDestinationKind.existingPlaylist;
        final id = target == 'folder' ? 'customId-folder' : 'customId-existing';
        final selected = {'recording-3', 'chosen-alternate-2'};
        final preview = service.preview(
          snapshot: snapshot,
          requestedCount: 0,
          destinationKind: kind,
          selectionKind: SpotifyImportSelectionKind.individual,
          selectedRecordingIds: selected,
          existingPlaylistId: id,
          newPlaylistName: 'Owned selected',
        );
        expect(preview.selectedSongs.map((song) => song['ytid']), [
          'chosen-alternate-2',
          'recording-3',
        ]);
        expect(preview.unresolvedCount, 1);
        final result = await service.route(
          snapshot: snapshot,
          requestedCount: 0,
          destinationKind: kind,
          selectionKind: SpotifyImportSelectionKind.individual,
          selectedRecordingIds: selected,
          existingPlaylistId: id,
          newPlaylistName: 'Owned selected',
        );
        expect(result.addedCount, 2);
        await reopen();
        final songs = target == 'liked'
            ? userLikedSongsList.value
            : getUserCustomPlaylists().firstWhere(
                    (playlist) => target == 'new'
                        ? playlist['title'] == 'Owned selected'
                        : playlist['ytid'] == id,
                  )['list']
                  as List;
        expect(
          songs.map((song) => song['ytid']),
          target == 'liked'
              ? ['chosen-alternate-2', 'recording-3', 'keep-like']
              : target == 'new'
              ? ['chosen-alternate-2', 'recording-3']
              : [
                  target == 'folder' ? 'keep-folder' : 'keep-playlist',
                  'chosen-alternate-2',
                  'recording-3',
                ],
        );
        expect(Hive.box('user').get('spotifyMatchResults'), originalResults);
        expect(
          (metadata()['routingHistory'] as List).last['selectedRecordingIds'],
          ['chosen-alternate-2', 'recording-3'],
        );
        expect(
          (await service.loadSnapshot()).newlyResolvedRecordingIds,
          isEmpty,
        );
        final repeated = await service.route(
          snapshot: await service.loadSnapshot(),
          requestedCount: 0,
          destinationKind: kind,
          selectionKind: SpotifyImportSelectionKind.individual,
          selectedRecordingIds: selected,
          existingPlaylistId: id,
          newPlaylistName: 'Owned selected',
        );
        expect(repeated.addedCount, 0);
        expect(repeated.alreadyPresentCount, 2);
      },
    );
  }

  test(
    'newly resolved compares all prior rows including unselected, with changed alternatives',
    () async {
      await seed();
      await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.individual,
        selectedRecordingIds: {'recording-1'},
      );
      final rows = List<Map>.from(Hive.box('user').get('spotifyMatchResults'));
      rows[1] = Map.from(rows[1])
        ..['bestCandidate'] = recording(2, id: 'new-alternative-2');
      rows[3] = Map.from(rows[3])
        ..['status'] = 'manually_matched'
        ..['bestCandidate'] = recording(4);
      await Hive.box('user').put('spotifyMatchResults', rows);
      await reopen();
      final snapshot = await service.loadSnapshot();
      expect(snapshot.newlyResolvedRecordingIds, {
        'new-alternative-2',
        'recording-4',
      });
      expect(
        snapshot.newlyResolvedRecordingIds,
        isNot(contains('recording-3')),
      );
      final preview = service.preview(
        snapshot: snapshot,
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.newlyResolved,
      );
      expect(preview.selectedSongs.map((song) => song['ytid']), [
        'new-alternative-2',
        'recording-4',
      ]);
      await service.route(
        snapshot: snapshot,
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.newlyResolved,
      );
      final before = copyImportRoutingValue(metadata());
      await expectLater(
        service.route(
          snapshot: snapshot,
          requestedCount: 0,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
          selectionKind: SpotifyImportSelectionKind.newlyResolved,
        ),
        throwsStateError,
      );
      expect(metadata(), before);
      expect((await service.loadSnapshot()).newlyResolvedRecordingIds, isEmpty);
    },
  );

  test(
    'legacy counts stay unknown without mutation, then explicit transfer records a real baseline',
    () async {
      await seed(legacy: true);
      final before = copyImportRoutingValue(metadata()) as Map;
      final snapshot = await service.loadSnapshot();
      expect(snapshot.newlyResolvedBaselineKnown, isFalse);
      expect(metadata(), before);
      expect(
        () => service.selectSongs(
          snapshot,
          3,
          selectionKind: SpotifyImportSelectionKind.newlyResolved,
        ),
        throwsStateError,
      );
      await service.route(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      await reopen();
      expect(
        (metadata()['routingHistory'] as List).first,
        (before['routingHistory'] as List).first,
      );
      expect((await service.loadSnapshot()).newlyResolvedBaselineKnown, isTrue);
      expect(
        (metadata()[importRoutingBaselineKey] as Map)['resolvedRecordings'],
        hasLength(3),
      );
    },
  );

  test(
    'incomplete legacy row positions preserve stored order and remain honestly untracked',
    () async {
      await seed(legacy: true);
      final rows = List<Map>.from(Hive.box('user').get('spotifyMatchResults'));
      rows[1] = Map.from(rows[1])..remove('sourceRow');
      await Hive.box('user').put('spotifyMatchResults', rows);
      final snapshot = await service.loadSnapshot();
      expect(snapshot.resolvedSongs.map((song) => song['ytid']), [
        'recording-1',
        'chosen-alternate-2',
        'recording-3',
      ]);
      final result = await service.route(
        snapshot: snapshot,
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.individual,
        selectedRecordingIds: {'chosen-alternate-2'},
      );
      expect(result.trackingRecorded, isFalse);
      await reopen();
      expect(
        (await service.loadSnapshot()).newlyResolvedBaselineKnown,
        isFalse,
      );
      expect(Hive.box('user').get('spotifyMatchResults'), rows);
      expect(userLikedSongsList.value.first['ytid'], 'chosen-alternate-2');
    },
  );

  test(
    'missing, malformed, future and wrong-session baselines never masquerade as empty',
    () async {
      for (final value in [
        null,
        {'version': 2},
        {
          'version': 1,
          'reliable': true,
          'importSessionId': 'other',
          'resolvedRecordings': [],
        },
        {
          'version': 1,
          'reliable': true,
          'importSessionId': 'i11-session',
          'resolvedRecordings': ['bad'],
        },
      ]) {
        await seed();
        final changed = metadata()..[importRoutingBaselineKey] = value;
        await Hive.box('user').put('spotifyImportMetadata', changed);
        final snapshot = await service.loadSnapshot();
        expect(snapshot.newlyResolvedBaselineKnown, isFalse);
        expect(
          () => service.selectSongs(
            snapshot,
            1,
            selectionKind: SpotifyImportSelectionKind.newlyResolved,
          ),
          throwsStateError,
        );
        expect(metadata(), changed);
      }
    },
  );

  test('failed pre-write leaves destination and metadata exact', () async {
    await seed();
    final before = copyImportRoutingValue(metadata());
    final failing = SpotifyImportDestinationService(
      metadataWriter: (_, _) async {
        throw const FileSystemException('Owned pre-write failure');
      },
    );
    await expectLater(
      failing.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(userLikedSongsList.value.map((song) => song['ytid']), ['keep-like']);
    expect(metadata(), before);
  });

  test(
    'failed final audit keeps durable destination and unknown tracking across reopen',
    () async {
      await seed();
      var calls = 0;
      final failing = SpotifyImportDestinationService(
        metadataWriter: (box, values) async {
          if (++calls >= 2)
            throw const FileSystemException('Owned audit failure');
          await box.put('spotifyImportMetadata', values);
        },
      );
      final result = await failing.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(result.addedCount, 1);
      expect(result.trackingRecorded, isFalse);
      await reopen();
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'recording-1',
        'keep-like',
      ]);
      expect(
        (await service.loadSnapshot()).newlyResolvedBaselineKnown,
        isFalse,
      );
      final priorAttempt = copyImportRoutingValue(
        metadata()[importRoutingPendingKey],
      );
      final retry = await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(retry.addedCount, 0);
      expect(retry.alreadyPresentCount, 1);
      expect(
        ((metadata()[importRoutingUnverifiedHistoryKey] as List).single
            as Map)['attempt'],
        priorAttempt,
      );
      expect((await service.loadSnapshot()).newlyResolvedBaselineKnown, isTrue);
    },
  );

  test(
    'row recording change and empty/unknown individual selection reject before writes',
    () async {
      await seed();
      final snapshot = await service.loadSnapshot();
      final rows = List<Map>.from(Hive.box('user').get('spotifyMatchResults'));
      rows[0] = Map.from(rows[0])
        ..['bestCandidate'] = recording(1, id: 'changed-recording');
      await Hive.box('user').put('spotifyMatchResults', rows);
      final before = copyImportRoutingValue(metadata());
      await expectLater(
        service.route(
          snapshot: snapshot,
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
        ),
        throwsStateError,
      );
      for (final ids in [
        <String>{},
        {'not-in-this-import'},
      ]) {
        await expectLater(
          service.route(
            snapshot: await service.loadSnapshot(),
            requestedCount: 0,
            destinationKind: SpotifyImportDestinationKind.likedSongs,
            selectionKind: SpotifyImportSelectionKind.individual,
            selectedRecordingIds: ids,
          ),
          throwsStateError,
        );
      }
      expect(metadata(), before);
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'keep-like',
      ]);
    },
  );

  test(
    'overlapping route is rejected while the confirmed destination writes once',
    () async {
      await seed();
      final gate = Completer<void>();
      final started = Completer<void>();
      var writes = 0;
      final controlled = SpotifyImportDestinationService(
        metadataWriter: (box, value) async {
          if (++writes == 1) {
            started.complete();
            await gate.future;
          }
          await box.put('spotifyImportMetadata', value);
        },
      );
      final snapshot = await service.loadSnapshot();
      final first = controlled.route(
        snapshot: snapshot,
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      await started.future;
      await expectLater(
        service.route(
          snapshot: snapshot,
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
        ),
        throwsStateError,
      );
      gate.complete();
      expect((await first).addedCount, 1);
      expect(metadata()['routingHistory'], hasLength(1));
    },
  );

  test(
    'matching checkpoint preserves newer routing state instead of resurrecting captured fields',
    () async {
      await seed();
      final box = Hive.box('user');
      await box.put('spotifyImportTracks', [
        {'sourceRow': 5, 'title': 'Owned skipped row'},
      ]);
      await box.put('spotifyMatchResults', []);
      await box.put('spotifyExcludedImportRows', ['5']);
      final initial = metadata()..['nextTrackIndex'] = 0;
      await box.put('spotifyImportMetadata', initial);
      Future<void>? pendingWrite;
      var updated = false;
      final newer = importRoutingBaseline(
        sessionId: 'i11-session',
        rows: [
          {'sourceRow': '2', 'recordingId': 'chosen-alternate-2'},
        ],
        recordedAt: '2026-01-03T00:00:00Z',
        reliable: true,
        reason: 'confirmed_transfer',
      );
      await const SpotifyTrackMatchingService().matchNextBatch(
        batchSize: 1,
        shouldPause: () {
          if (!updated) {
            updated = true;
            final value = metadata()
              ..[importRoutingBaselineKey] = newer
              ..[importRoutingPendingKey] = {'operationId': 'owned-pending'}
              ..['routingHistory'] = [
                {'selectedCount': 1},
              ]
              ..[importRoutingUnverifiedHistoryKey] = [
                {'status': 'unverified'},
              ];
            pendingWrite = box.put('spotifyImportMetadata', value);
          }
          return false;
        },
      );
      await pendingWrite;
      expect(metadata()[importRoutingBaselineKey], newer);
      expect(metadata()[importRoutingPendingKey], {
        'operationId': 'owned-pending',
      });
      expect(metadata()[importRoutingUnverifiedHistoryKey], [
        {'status': 'unverified'},
      ]);
      expect(metadata()['routingHistory'], [
        {'selectedCount': 1},
      ]);
    },
  );

  test(
    'verified backup round trip retains legacy audit, baseline and interrupted-attempt evidence',
    () async {
      await seed(legacy: true);
      await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 0,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
        selectionKind: SpotifyImportSelectionKind.individual,
        selectedRecordingIds: {'chosen-alternate-2'},
      );
      final before = copyImportRoutingValue(metadata());
      await Hive.box('user').flush();
      await Hive.box('settings').flush();
      final payloads = {
        for (final name in ['user', 'settings'])
          name: Uint8List.fromList(
            await File(Hive.box(name).path!).readAsBytes(),
          ),
      };
      final bundle = await MusifyBackupService.createBundleBytesForTesting(
        payloads,
      );
      final inspected = await MusifyBackupService.inspectBundleBytes(
        bundle,
        sourceDescription: 'owned-i11',
      );
      await Hive.box(
        'user',
      ).put('spotifyImportMetadata', {'importSessionId': 'different'});
      final restored = await MusifyBackupService.restoreValidatedBackup(
        inspected,
      );
      expect(restored.success, isTrue);
      await reopen();
      expect(metadata(), before);
      expect((await service.loadSnapshot()).newlyResolvedBaselineKnown, isTrue);
      expect((await service.loadSnapshot()).newlyResolvedRecordingIds, isEmpty);
    },
  );
}
