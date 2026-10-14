import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_song_list_importer.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import '../support/spotify_playlist_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source-route-');
    Hive.init(root.path);
    await Hive.openBox('user');
    await Hive.openBox('settings');
    await const SpotifyImportSessionService().saveNewImport(
      SpotifySongListImporter.parseBytes(
        SpotifyPlaylistFixture.bytes(),
        fileName: 'account.json',
      ),
    );
    SpotifyPlaylistMember member(int position, int? row) =>
        SpotifyPlaylistMember(
          position: position,
          sourceRow: row,
          issue: row == null ? 'Unavailable' : null,
          sourceMetadata: row == null
              ? const {}
              : {'uri': 'spotify:track:${(row == 1 ? 'A' : 'B') * 22}'},
        );
    final sources = [
      SpotifySourcePlaylist(
        position: 1,
        name: 'Same',
        spotifyUri: null,
        members: [member(1, 1)],
      ),
      SpotifySourcePlaylist(
        position: 2,
        name: 'Same',
        spotifyUri: null,
        members: [member(1, 4), member(2, 1), member(3, 4), member(4, null)],
      ),
    ];
    final box = Hive.box('user');
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    metadata['sourcePlaylists'] = SpotifySourcePlaylistCodec.encode(sources);
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
      'customPlaylists': [
        {
          'ytid': 'keep-existing',
          'title': 'Same',
          'source': 'user-created',
          'importSourceName': 'Same',
          'list': [
            {'ytid': 'keep', 'title': 'Keep'},
          ],
        },
      ],
      'likedSongs': <dynamic>[],
    });
    reloadPlaylistLibraryStateFromStorage();
    userLikedSongsList.value = [];
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  const service = SpotifyImportDestinationService();
  Object sourceData() => jsonDecode(
    jsonEncode(
      Hive.box('user').get('spotifyImportMetadata')['sourcePlaylists'],
    ),
  );
  test(
    'source order chosen alternatives separate same-name targets and repeat/restart idempotence',
    () async {
      final before = sourceData();
      final second = await service.loadSourcePlaylistSnapshot(2);
      expect(second.resolvedSongs.map((s) => s['ytid']), [
        'chosen-B',
        'chosen-A',
      ]);
      expect(second.sourceUnsupportedMembers, 1);
      expect(second.sourceRepeatedMembers, 1);
      final first = await service.loadSourcePlaylistSnapshot(1);
      await service.route(
        snapshot: first,
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        selectionKind: SpotifyImportSelectionKind.all,
        newPlaylistName: 'Same',
      );
      var result = await service.route(
        snapshot: second,
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        selectionKind: SpotifyImportSelectionKind.all,
        newPlaylistName: 'Same',
      );
      expect(result.addedCount, 2);
      var playlists = getUserCustomPlaylists();
      expect(playlists, hasLength(3));
      expect(
        (playlists.firstWhere((p) => p['ytid'] == 'keep-existing')['list']
                as List)
            .single['ytid'],
        'keep',
      );
      final scoped = playlists.singleWhere(
        (p) => p['importSourcePlaylistKey'] == second.sourcePlaylistKey,
      );
      expect((scoped['list'] as List).map((s) => s['ytid']), [
        'chosen-B',
        'chosen-A',
      ]);
      expect(sourceData(), before);
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      reloadPlaylistLibraryStateFromStorage();
      result = await service.route(
        snapshot: await service.loadSourcePlaylistSnapshot(2),
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        selectionKind: SpotifyImportSelectionKind.all,
        newPlaylistName: 'Same',
      );
      expect(result.addedCount, 0);
      expect(result.alreadyPresentCount, 2);
      expect(getUserCustomPlaylists(), hasLength(3));
      expect(sourceData(), before);
    },
  );
  test('stale membership rejects before changing any destination', () async {
    final snapshot = await service.loadSourcePlaylistSnapshot(2);
    final box = Hive.box('user');
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    metadata['sourcePlaylists']['playlists'][1]['name'] = 'Changed';
    await box.put('spotifyImportMetadata', metadata);
    final before = jsonDecode(jsonEncode(box.toMap()));
    await expectLater(
      service.route(
        snapshot: snapshot,
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        selectionKind: SpotifyImportSelectionKind.all,
        newPlaylistName: 'Same',
      ),
      throwsStateError,
    );
    expect(box.toMap(), before);
  });
  test(
    'metadata admission failure leaves destination and source state untouched',
    () async {
      final box = Hive.box('user');
      final before = jsonDecode(jsonEncode(box.toMap()));
      final failing = SpotifyImportDestinationService(
        metadataWriter: (_, _) async =>
            throw StateError('Owned failed admission'),
      );
      await expectLater(
        failing.route(
          snapshot: await service.loadSourcePlaylistSnapshot(2),
          requestedCount: 99,
          destinationKind: SpotifyImportDestinationKind.newPlaylist,
          selectionKind: SpotifyImportSelectionKind.all,
          newPlaylistName: 'Same',
        ),
        throwsStateError,
      );
      expect(box.toMap(), before);
    },
  );
  test(
    'partial destination write rolls back owned state and retry retains sources',
    () async {
      final box = Hive.box('user');
      final before = jsonDecode(jsonEncode(box.get('customPlaylists')));
      final sources = sourceData();
      final failing = SpotifyImportDestinationService(
        destinationWriter: (target, key, value) async {
          await target.put(key, value);
          throw StateError('Owned partial destination write');
        },
      );
      await expectLater(
        failing.route(
          snapshot: await service.loadSourcePlaylistSnapshot(2),
          requestedCount: 99,
          destinationKind: SpotifyImportDestinationKind.newPlaylist,
          newPlaylistName: 'Same',
          selectionKind: SpotifyImportSelectionKind.all,
        ),
        throwsStateError,
      );
      expect(box.get('customPlaylists'), before);
      expect(sourceData(), sources);
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      reloadPlaylistLibraryStateFromStorage();
      expect(Hive.box('user').get('customPlaylists'), before);
      final result = await service.route(
        snapshot: await service.loadSourcePlaylistSnapshot(2),
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Same',
        selectionKind: SpotifyImportSelectionKind.all,
      );
      expect(result.addedCount, 2);
      expect(sourceData(), sources);
    },
  );
  test(
    'failed writer does not roll back a newer independent destination edit',
    () async {
      final box = Hive.box('user');
      final sources = sourceData();
      final later = [
        {
          'ytid': 'independent',
          'title': 'Keep later edit',
          'source': 'user-created',
          'list': <dynamic>[],
        },
      ];
      final failing = SpotifyImportDestinationService(
        destinationWriter: (target, key, value) async {
          await target.put(key, value);
          await target.put(key, later);
          throw StateError('Owned failure after independent edit');
        },
      );
      await expectLater(
        failing.route(
          snapshot: await service.loadSourcePlaylistSnapshot(2),
          requestedCount: 99,
          destinationKind: SpotifyImportDestinationKind.newPlaylist,
          newPlaylistName: 'Same',
          selectionKind: SpotifyImportSelectionKind.all,
        ),
        throwsStateError,
      );
      expect(box.get('customPlaylists'), later);
      expect(sourceData(), sources);
    },
  );
  test(
    'source target keys and order survive saved-file restore independently',
    () async {
      await service.route(
        snapshot: await service.loadSourcePlaylistSnapshot(2),
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Same',
        selectionKind: SpotifyImportSelectionKind.all,
      );
      final user = Hive.box('user'), settings = Hive.box('settings');
      await user.flush();
      await settings.flush();
      final before = jsonDecode(jsonEncode(user.toMap()));
      final saved =
          await MusifyBackupService.createStreamedBundleFileForTesting({
            'user': await File(user.path!).readAsBytes(),
            'settings': await File(settings.path!).readAsBytes(),
          }, root);
      final verified = await MusifyBackupService.inspectBundleFileForTesting(
        saved,
      );
      await user.clear();
      await user.put('sentinel', 'owned restore');
      final result = await MusifyBackupService.restoreValidatedBackup(verified);
      expect(result.success, isTrue, reason: result.message);
      await Hive.close();
      await Hive.openBox('user');
      await Hive.openBox('settings');
      expect(Hive.box('user').toMap(), before);
      reloadPlaylistLibraryStateFromStorage();
      final retry = await service.route(
        snapshot: await service.loadSourcePlaylistSnapshot(2),
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Same',
        selectionKind: SpotifyImportSelectionKind.all,
      );
      expect(retry.addedCount, 0);
    },
  );
  test(
    'failed owned write restores an originally absent destination key',
    () async {
      final box = Hive.box('user');
      await box.delete('customPlaylists');
      reloadPlaylistLibraryStateFromStorage();
      final before = sourceData();
      final failing = SpotifyImportDestinationService(
        destinationWriter: (target, key, value) async {
          await target.put(key, value);
          throw StateError('Owned failed first destination');
        },
      );
      await expectLater(
        failing.route(
          snapshot: await service.loadSourcePlaylistSnapshot(2),
          requestedCount: 99,
          destinationKind: SpotifyImportDestinationKind.newPlaylist,
          newPlaylistName: 'Same',
          selectionKind: SpotifyImportSelectionKind.all,
        ),
        throwsStateError,
      );
      expect(box.containsKey('customPlaylists'), isFalse);
      expect(sourceData(), before);
    },
  );
  test(
    'membership changed after destination write is retained with unverified tracking',
    () async {
      final box = Hive.box('user');
      final writer = SpotifyImportDestinationService(
        destinationWriter: (target, key, value) async {
          await target.put(key, value);
          final metadata = Map<String, dynamic>.from(
            target.get('spotifyImportMetadata') as Map,
          );
          metadata['sourcePlaylists']['playlists'][1]['name'] =
              'Changed after confirmed write';
          await target.put('spotifyImportMetadata', metadata);
        },
      );
      final result = await writer.route(
        snapshot: await service.loadSourcePlaylistSnapshot(2),
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
        newPlaylistName: 'Same',
        selectionKind: SpotifyImportSelectionKind.all,
      );
      expect(result.addedCount, 2);
      expect(result.trackingRecorded, isFalse);
      expect(
        box.get(
          'spotifyImportMetadata',
        )['sourcePlaylists']['playlists'][1]['name'],
        'Changed after confirmed write',
      );
      expect((box.get('customPlaylists') as List).length, 2);
    },
  );
}
