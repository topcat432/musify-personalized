import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_track_matching_service.dart';
import 'package:musify/services/musify_backup_service.dart';

const identityA = 'AbCdEfGhIjKlMnOpQrStUv';
const identityB = 'ZbCdEfGhIjKlMnOpQrStUv';

SpotifyImportPreview preview(
  String uri, {
  String id = '',
  String idHeader = 'Spotify Track ID',
}) => SpotifyCsvImporter.parseBytes(
  Uint8List.fromList(
    utf8.encode(
      'Track URI,$idHeader,title,artist,album,isrc,duration_ms\n'
      '$uri,$id,Owned One,Synthetic Artist,Synthetic Album,ZZAAA2600001,120000\n',
    ),
  ),
  fileName: 'synthetic.csv',
);

Map<String, dynamic> candidate() => {
  'ytid': 'owned-choice-one',
  'title': 'Owned One',
  'artist': 'Synthetic Artist',
  'album': 'Synthetic Album',
  'duration': 120,
  'isrc': 'ZZAAA2600001',
  'sourceType': 'youtube_music_song',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('syntactic Spotify metadata intake, never lookup or entitlement', () {
    for (final uri in [
      'spotify:track:$identityA',
      ' https://open.spotify.com/track/$identityA?si=synthetic#fragment ',
      'https://open.spotify.com/intl-es/track/$identityA/',
      'https://open.spotify.com:443/track/$identityA',
    ]) {
      test('canonicalizes supported form $uri', () {
        final track = preview(uri).tracks.single;
        expect(track.spotifyTrackUri, 'spotify:track:$identityA');
        expect(track.spotifyTrackId, identityA);
        expect(track.toJson()['spotifyTrackUri'], 'spotify:track:$identityA');
        expect(track.toJson()['spotifyTrackId'], identityA);
        expect(
          jsonEncode(track.toJson()),
          isNot(contains('synthetic#fragment')),
        );
      });
    }
    for (final uri in [
      'spotify:track:short',
      'spotify:album:$identityA',
      'https://open.spotify.com/episode/$identityA',
      'http://open.spotify.com/track/$identityA',
      'https://open.spotify.com.evil.invalid/track/$identityA',
      'https://spotify.link/synthetic',
      'https://fixture:fixture@open.spotify.com/track/$identityA',
      'https://open.spotify.com:444/track/$identityA',
      'https://open.spotify.com/track/$identityA/extra',
      'https://open.spotify.com/track/%41bCdEfGhIjKlMnOpQrStUv',
    ]) {
      test('rejects identity metadata, keeps usable row $uri', () {
        final parsed = preview(uri, id: identityA);
        expect(parsed.tracks.single.title, 'Owned One');
        expect(parsed.rejectedRows, isEmpty);
        expect(
          parsed.tracks.single.toJson().containsKey('spotifyTrackUri'),
          isFalse,
        );
        expect(
          parsed.tracks.single.toJson().containsKey('spotifyTrackId'),
          isFalse,
        );
      });
    }
    test('only explicit Spotify ID header supplies ID-only identity', () {
      expect(
        preview('', id: identityA).tracks.single.spotifyTrackUri,
        'spotify:track:$identityA',
      );
      expect(
        preview(
          '',
          id: identityA,
          idHeader: 'Track ID',
        ).tracks.single.spotifyTrackUri,
        isNull,
      );
    });
    test('URI/ID must agree exactly and preserve ID case', () {
      expect(
        preview(
          'spotify:track:$identityA',
          id: identityA,
        ).tracks.single.spotifyTrackId,
        identityA,
      );
      for (final id in [identityB, identityA.toLowerCase(), 'invalid']) {
        expect(
          preview(
            'spotify:track:$identityA',
            id: id,
          ).tracks.single.spotifyTrackUri,
          isNull,
        );
      }
    });
    test('missing metadata retains exact legacy serialized shape', () {
      expect(preview('').tracks.single.toJson(), {
        'sourceRow': 2,
        'title': 'Owned One',
        'artist': 'Synthetic Artist',
        'album': 'Synthetic Album',
        'isrc': 'ZZAAA2600001',
        'durationMs': 120000,
        'addedAt': null,
      });
    });
    test('direct model serialization cannot persist inconsistent identity', () {
      const track = SpotifyImportTrack(
        sourceRow: 2,
        title: 'Owned',
        artist: 'Synthetic',
        album: '',
        isrc: '',
        durationMs: null,
        addedAt: null,
        spotifyTrackUri: 'spotify:track:$identityA',
        spotifyTrackId: identityB,
      );
      expect(track.toJson().containsKey('spotifyTrackUri'), isFalse);
      expect(track.toJson().containsKey('spotifyTrackId'), isFalse);
    });
  });

  group('optional fields across Hive checkpoints', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('spotify-identity-');
      Hive.init(root.path);
      for (final name in ['user', 'settings', 'userNoBackup', 'cache'])
        await Hive.openBox(name);
    });
    tearDown(() async {
      await Hive.close();
      await root.delete(recursive: true);
    });
    Future<void> reopen() async {
      await Hive.close();
      Hive.init(root.path);
      for (final name in ['user', 'settings', 'userNoBackup', 'cache'])
        await Hive.openBox(name);
    }

    test(
      'new import survives pause/reopen/resume without changing matching or routing payload',
      () async {
        final p = preview('spotify:track:$identityA');
        final tracks = [
          p.tracks.single.toJson(),
          {
            ...p.tracks.single.toJson(),
            'sourceRow': 3,
            'spotifyTrackUri': 'spotify:track:$identityB',
            'spotifyTrackId': identityB,
          },
        ];
        await const SpotifyImportSessionService().saveNewImport(p);
        await Hive.box('user').put('spotifyImportTracks', tracks);
        await Hive.box('user').put('likedSongs', [
          {'ytid': 'keep-owned'},
        ]);
        var lookups = 0;
        final queries = <String>[];
        final service = SpotifyTrackMatchingService(
          musicLookup: (query) async {
            lookups++;
            queries.add(query);
            return [candidate()];
          },
          videoLookup: (_) async => [],
        );
        await service.matchNextBatch(
          batchSize: 2,
          shouldPause: () => lookups > 0,
        );
        final first = Map.from(
          (Hive.box('user').get('spotifyMatchResults') as List).single,
        );
        expect(first['spotifyTrackId'], identityA);
        expect(first['status'], 'matched');
        await reopen();
        expect(Hive.box('user').get('spotifyImportTracks'), tracks);
        await service.matchNextBatch(batchSize: 2);
        final results = Hive.box('user').get('spotifyMatchResults') as List;
        expect(results.first, first);
        expect((results.last as Map)['spotifyTrackId'], identityB);
        expect(lookups, 2);
        expect(queries, [
          'Synthetic Artist Owned One',
          'Synthetic Artist Owned One',
        ]);
        expect(Hive.box('user').get('likedSongs'), [
          {'ytid': 'keep-owned'},
        ]);
        final songs =
            (await const SpotifyImportDestinationService().loadSnapshot())
                .resolvedSongs;
        expect(songs, [
          {
            ...candidate(),
            'importSourceRow': 2,
            'importSourceTitle': 'Owned One',
            'importSourceArtist': 'Synthetic Artist',
          },
        ]);
        expect(songs.single.containsKey('spotifyTrackUri'), isFalse);
      },
    );
    test(
      'legacy and partial stored fields pass through without backfill/classification changes',
      () async {
        final old = preview('').tracks.single.toJson();
        final tracks = [
          old,
          {
            ...old,
            'sourceRow': 3,
            'spotifyTrackUri': 'spotify:track:$identityA',
          },
          {...old, 'sourceRow': 4, 'spotifyTrackId': null},
        ];
        await Hive.box('user').putAll({
          'spotifyImportTracks': tracks,
          'spotifyImportMetadata': {'importSessionId': 'synthetic'},
        });
        final service = SpotifyTrackMatchingService(
          musicLookup: (_) async => [candidate()],
          videoLookup: (_) async => [],
        );
        await service.matchNextBatch(batchSize: 3);
        await reopen();
        final results = Hive.box('user').get('spotifyMatchResults') as List;
        expect((results[0] as Map).containsKey('spotifyTrackUri'), isFalse);
        expect(
          (results[1] as Map)['spotifyTrackUri'],
          'spotify:track:$identityA',
        );
        expect((results[1] as Map).containsKey('spotifyTrackId'), isFalse);
        expect((results[2] as Map)['spotifyTrackId'], isNull);
        expect(
          results.map((r) => (r as Map)['status']),
          everyElement('matched'),
        );
        expect(
          results.map((r) => (r as Map)['bestCandidate']),
          everyElement(candidate()),
        );
        expect(Hive.box('user').get('spotifyImportTracks'), tracks);
      },
    );
    test(
      'excluded and failed lookup checkpoints retain source fields and original states',
      () async {
        final row = preview('spotify:track:$identityA').tracks.single.toJson();
        await Hive.box('user').putAll({
          'spotifyImportTracks': [
            row,
            {...row, 'sourceRow': 3},
          ],
          'spotifyExcludedImportRows': ['2'],
          'spotifyImportMetadata': {'importSessionId': 'synthetic'},
        });
        final service = SpotifyTrackMatchingService(
          musicLookup: (_) async => throw StateError('owned failure'),
          videoLookup: (_) async => throw StateError('owned failure'),
        );
        await service.matchNextBatch(batchSize: 2);
        await reopen();
        final results = Hive.box('user').get('spotifyMatchResults') as List;
        expect(results.map((r) => (r as Map)['status']), ['excluded', 'error']);
        expect(
          results.map((r) => (r as Map)['spotifyTrackUri']),
          everyElement('spotify:track:$identityA'),
        );
      },
    );
    test('a changed optional identity rejects a stale checkpoint', () async {
      final row = preview('spotify:track:$identityA').tracks.single.toJson();
      await Hive.box('user').putAll({
        'spotifyImportTracks': [row],
        'spotifyImportMetadata': {'importSessionId': 'synthetic'},
      });
      final service = SpotifyTrackMatchingService(
        musicLookup: (_) async {
          await Hive.box('user').put('spotifyImportTracks', [
            {
              ...row,
              'spotifyTrackUri': 'spotify:track:$identityB',
              'spotifyTrackId': identityB,
            },
          ]);
          return [candidate()];
        },
        videoLookup: (_) async => [],
      );
      await service.matchNextBatch(batchSize: 1);
      expect(
        Hive.box('user').get('spotifyMatchResults', defaultValue: []),
        isEmpty,
      );
      expect(
        ((Hive.box('user').get('spotifyImportTracks') as List).single
            as Map)['spotifyTrackId'],
        identityB,
      );
    });
    test(
      'partial failed replacement restores exact old identity/selection and reopens',
      () async {
        final old = {
          'spotifyImportTracks': [
            preview('spotify:track:$identityA').tracks.single.toJson(),
          ],
          'spotifyImportMetadata': {
            'matchingStatus': 'complete',
            'importSessionId': 'old',
            'routingHistory': [
              {'addedCount': 1},
            ],
          },
          'spotifyMatchResults': [
            {
              'sourceRow': 2,
              'status': 'manually_matched',
              'spotifyTrackUri': 'spotify:track:$identityA',
              'bestCandidate': {'ytid': 'keep-selected'},
            },
          ],
          'spotifyExcludedImportRows': ['3'],
          'likedSongs': [
            {'ytid': 'keep-owned'},
          ],
        };
        await Hive.box('user').putAll(old);
        final service = SpotifyImportSessionService(
          sessionWriter: (box, values) async {
            await box.put('spotifyImportTracks', values['spotifyImportTracks']);
            throw StateError('owned partial write');
          },
        );
        await expectLater(
          service.saveNewImport(preview('spotify:track:$identityB')),
          throwsStateError,
        );
        await reopen();
        expect(Hive.box('user').toMap(), old);
      },
    );
    test(
      'cancelled lookup checkpoints no result and resumes with source identity',
      () async {
        await const SpotifyImportSessionService().saveNewImport(
          preview('spotify:track:$identityA'),
        );
        final original = Hive.box('user').get('spotifyImportTracks');
        var cancelled = false;
        final interrupted = SpotifyTrackMatchingService(
          musicLookup: (_) async {
            cancelled = true;
            return [candidate()];
          },
          videoLookup: (_) async => [],
        );
        await interrupted.matchNextBatch(
          batchSize: 1,
          shouldCancel: () => cancelled,
        );
        await reopen();
        expect(Hive.box('user').get('spotifyImportTracks'), original);
        expect(Hive.box('user').get('spotifyMatchResults'), isEmpty);
        expect(
          (Hive.box('user').get('spotifyImportMetadata')
              as Map)['nextTrackIndex'],
          0,
        );
        final resumed = SpotifyTrackMatchingService(
          musicLookup: (_) async => [candidate()],
          videoLookup: (_) async => [],
        );
        await resumed.matchNextBatch(batchSize: 1);
        expect(
          ((Hive.box('user').get('spotifyMatchResults') as List).single
              as Map)['spotifyTrackId'],
          identityA,
        );
      },
    );
    test(
      'schema-one saved backup preserves optional fields through independent restore/reopen',
      () async {
        await const SpotifyImportSessionService().saveNewImport(
          preview('spotify:track:$identityA'),
        );
        await Hive.box('settings').put('keepSetting', 42);
        final service = SpotifyTrackMatchingService(
          musicLookup: (_) async => [candidate()],
          videoLookup: (_) async => [],
        );
        await service.matchNextBatch(batchSize: 1);
        final expectedUser = Hive.box('user').toMap();
        final expectedSettings = Hive.box('settings').toMap();
        for (final name in ['user', 'settings']) await Hive.box(name).flush();
        final payloads = <String, Uint8List>{
          for (final name in ['user', 'settings'])
            name: await File(Hive.box(name).path!).readAsBytes(),
        };
        final file =
            await MusifyBackupService.createStreamedBundleFileForTesting(
              payloads,
              root,
            );
        final validated = await MusifyBackupService.inspectBundleFileForTesting(
          file,
          sourceDescription: 'owned-provenance.musifybackup',
        );
        expect(validated.summary.importedTracks, 1);
        for (final name in ['user', 'settings'])
          expect(validated.payloads[name], orderedEquals(payloads[name]!));
        await Hive.close();
        final restored = Directory('${root.path}/independent-restored')
          ..createSync();
        for (final name in ['user', 'settings'])
          await File(
            '${restored.path}/$name.hive',
          ).writeAsBytes(validated.payloads[name]!, flush: true);
        for (var restart = 0; restart < 2; restart++) {
          Hive.init(restored.path);
          for (final name in ['user', 'settings']) await Hive.openBox(name);
          expect(Hive.box('user').toMap(), expectedUser);
          expect(Hive.box('settings').toMap(), expectedSettings);
          await Hive.close();
        }
      },
    );
  });
}
