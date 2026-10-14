import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_song_list_importer.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/services/spotify_track_matching_service.dart';
import '../support/spotify_playlist_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('playlist-session-');
    Hive.init(root.path);
    await Hive.openBox('user');
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  SpotifyImportPreview preview() => SpotifySongListImporter.parseBytes(
    SpotifyPlaylistFixture.bytes(),
    fileName: 'playlists.json',
  );
  Object snapshot() => jsonDecode(jsonEncode(Hive.box('user').toMap()));
  for (final prior in [
    <String, dynamic>{'fileName': 'old.csv'},
    <String, dynamic>{
      'version': 1,
      'fileName': 'partial.json',
      'nextTrackIndex': 3,
    },
  ]) {
    test(
      'membership partial-write rollback retains legacy state ${prior['fileName']}',
      () async {
        await Hive.box('user').putAll({
          'spotifyImportMetadata': prior,
          'spotifyMatchResults': [
            {'status': 'accepted', 'ytid': 'old'},
          ],
          'likedSongs': ['keep'],
        });
        final before = snapshot();
        await expectLater(
          SpotifyImportSessionService(
            sessionWriter: (box, values) async {
              await box.putAll(values);
              throw StateError('Owned failure');
            },
          ).saveNewImport(preview()),
          throwsStateError,
        );
        expect(snapshot(), before);
        await Hive.close();
        await Hive.openBox('user');
        expect(snapshot(), before);
        await const SpotifyImportSessionService().saveNewImport(preview());
        await Hive.close();
        await Hive.openBox('user');
        final sources = SpotifySourcePlaylistCodec.decode(
          Hive.box('user').get('spotifyImportMetadata')['sourcePlaylists'],
        );
        expect(sources.map((s) => s.name), ['One', 'Two', 'Empty']);
        expect(sources.first.members.map((m) => m.sourceRow), [1, null, 1]);
        expect(
          sources[1].members.last.sourceMetadata['addedAt'],
          '2026-10-01T12:00:00Z',
        );
        expect(Hive.box('user').get('likedSongs'), ['keep']);
        await const SpotifyImportSessionService().saveNewImport(
          SpotifyCsvImporter.parseBytes(
            Uint8List.fromList(utf8.encode('Title,Artist\nNext,Owner\n')),
            fileName: 'next.csv',
          ),
        );
        expect(
          (Hive.box('user').get('spotifyImportMetadata') as Map).containsKey(
            'sourcePlaylists',
          ),
          isFalse,
        );
      },
    );
  }
  test(
    'membership saved-file inspection restore and restart preserve full inventory',
    () async {
      await Hive.box('user').put('likedSongs', ['keep']);
      await const SpotifyImportSessionService().saveNewImport(preview());
      final user = Hive.box('user'), settings = Hive.box('settings');
      await settings.put('wrappedEnabled', true);
      await user.flush();
      await settings.flush();
      final before = snapshot();
      final payloads = {
        'user': await File(user.path!).readAsBytes(),
        'settings': await File(settings.path!).readAsBytes(),
      };
      final file = await MusifyBackupService.createStreamedBundleFileForTesting(
        payloads,
        root,
      );
      final inspected = await MusifyBackupService.inspectBundleFileForTesting(
        file,
      );
      await user.clear();
      await user.put('sentinel', 'owned test');
      final result = await MusifyBackupService.restoreValidatedBackup(
        inspected,
      );
      expect(result.success, isTrue, reason: result.message);
      await Hive.close();
      await Hive.openBox('user');
      expect(snapshot(), before);
    },
  );
  test(
    'old absence is readable; unknown version and broken positions reject',
    () {
      expect(SpotifySourcePlaylistCodec.decode(null), isEmpty);
      expect(
        () =>
            SpotifySourcePlaylistCodec.decode({'version': 2, 'playlists': []}),
        throwsFormatException,
      );
      final value = SpotifySourcePlaylistCodec.encode(
        preview().sourcePlaylists,
      );
      (value['playlists'] as List).first['members'][0]['position'] = 3;
      expect(
        () => SpotifySourcePlaylistCodec.decode(value),
        throwsFormatException,
      );
    },
  );
  test(
    'missing membership recording rejects before any durable write',
    () async {
      await Hive.box('user').put('likedSongs', ['keep']);
      final before = snapshot();
      final good = preview();
      final bad = SpotifyImportPreview(
        fileName: good.fileName,
        format: good.format,
        totalDataRows: good.totalDataRows,
        tracks: const [],
        rejectedRows: const [],
        sourcePlaylists: good.sourcePlaylists,
      );
      await expectLater(
        const SpotifyImportSessionService().saveNewImport(bad),
        throwsFormatException,
      );
      expect(snapshot(), before);
      await const SpotifyImportSessionService().saveNewImport(good);
    },
  );
  test(
    'chosen recording routing and retry preserve every source membership after restart',
    () async {
      await const SpotifyImportSessionService().saveNewImport(preview());
      final box = Hive.box('user');
      await box.putAll({
        'likedSongs': [
          {'ytid': 'keep', 'title': 'Keep'},
        ],
        'spotifyMatchResults': [
          {
            'sourceRow': 1,
            'status': 'manually_matched',
            'bestCandidate': {
              'ytid': 'chosen-alternative',
              'title': 'Chosen alternative',
            },
          },
        ],
      });
      userLikedSongsList.value = List.from(box.get('likedSongs'));
      final sourceBefore = jsonDecode(
        jsonEncode(box.get('spotifyImportMetadata')['sourcePlaylists']),
      );
      const service = SpotifyImportDestinationService();
      var result = await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(result.addedCount, 1);
      result = await service.route(
        snapshot: await service.loadSnapshot(),
        requestedCount: 1,
        destinationKind: SpotifyImportDestinationKind.likedSongs,
      );
      expect(result.addedCount, 0);
      expect(box.get('spotifyImportMetadata')['sourcePlaylists'], sourceBefore);
      expect((box.get('likedSongs') as List).map((s) => s['ytid']), [
        'chosen-alternative',
        'keep',
      ]);
      await Hive.close();
      await Hive.openBox('user');
      expect(
        Hive.box('user').get('spotifyImportMetadata')['sourcePlaylists'],
        sourceBefore,
      );
    },
  );
  test(
    'matching processes unique recordings and checkpoints retain memberships',
    () async {
      await const SpotifyImportSessionService().saveNewImport(preview());
      final box = Hive.box('user');
      final before = jsonDecode(
        jsonEncode(box.get('spotifyImportMetadata')['sourcePlaylists']),
      );
      final service = SpotifyTrackMatchingService(
        musicLookup: (_) async => [],
        videoLookup: (_) async => [],
      );
      final result = await service.matchNextBatch(batchSize: 25);
      expect(result.totalTracks, 2);
      expect(result.nextTrackIndex, 2);
      expect(
        (box.get('spotifyMatchResults') as List).map((r) => r['sourceRow']),
        [1, 4],
      );
      expect(box.get('spotifyImportMetadata')['sourcePlaylists'], before);
      await service.restartMatching();
      expect(box.get('spotifyImportMetadata')['sourcePlaylists'], before);
      await Hive.close();
      await Hive.openBox('user');
      expect(
        Hive.box('user').get('spotifyImportMetadata')['sourcePlaylists'],
        before,
      );
    },
  );
}
