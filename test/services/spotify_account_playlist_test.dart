import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_zip_importer.dart';
import 'package:musify/services/spotify_playlist_draft.dart';
import 'package:musify/services/spotify_song_list_importer.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/spotify_account_playlists.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  Uint8List bytes(Object value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));
  SpotifyImportPreview parse(Map<String, dynamic> value) =>
      SpotifySongListImporter.parseBytes(
        bytes(value),
        fileName: 'Playlist1.json',
      );
  List sources(Map<String, dynamic> value) => value['playlists'] as List;
  List items(Map<String, dynamic> value) =>
      sources(value).first['items'] as List;
  final rejected = throwsA(isA<SpotifyImportException>());

  test(
    'account fixture enters the production file route and preserves ordered gaps and repeats',
    () {
      final value = fixture();
      final before = jsonEncode(value);
      final preview = parse(value);
      expect(preview.format, 'Spotify account playlists');
      expect(preview.totalDataRows, 5);
      expect(preview.tracks.map((track) => track.sourceRow), [1, 3]);
      expect(preview.tracks.map((track) => track.spotifyTrackId), [
        'A' * 22,
        'B' * 22,
      ]);
      expect(
        preview.sourcePlaylists.first.members.map((member) => member.sourceRow),
        [1, null, 3, 1],
      );
      expect(preview.sourcePlaylists.last.members.single.sourceRow, 3);
      expect(
        preview.sourcePlaylists.map((source) => source.spotifyUri),
        everyElement(isNull),
      );
      expect(preview.sourcePlaylists[1].members, isEmpty);
      expect(preview.rejectedRows, hasLength(1));
      expect(
        preview.sourcePlaylists.first.members.last.sourceMetadata['addedAt'],
        '2026-09-04',
      );
      expect(
        preview.tracks.every(
          (track) => track.durationMs == null && track.addedAt == null,
        ),
        isTrue,
      );
      expect(jsonEncode(value), before);
      final stored = SpotifySourcePlaylistCodec.encode(preview.sourcePlaylists);
      expect(
        SpotifySourcePlaylistCodec.encode(
          SpotifySourcePlaylistCodec.readSaved(
            stored,
            preview.tracks.map((track) => track.toJson()).toList(),
          ),
        ),
        stored,
      );
    },
  );

  test('stored ZIP uses the same account adapter and retains selected-entry provenance', () async {
    // Independently produced with Python zipfile ZIP_STORED; synthetic only.
    final archive = base64Decode('UEsDBBQAAAAAAAAAQV2Io5cdKQIAACkCAAAOAAAAUGxheWxpc3QxLmpzb257InBsYXlsaXN0cyI6W3sibmFtZSI6IlN5bnRoZXRpYyBvcmRlcmVkIG1peCIsImxhc3RNb2RpZmllZERhdGUiOiIyMDI2LTEwLTAxIiwiaXRlbXMiOlt7InRyYWNrIjp7InRyYWNrTmFtZSI6IlN5bnRoZXRpYyBmaXJzdCIsImFydGlzdE5hbWUiOiJTeW50aGV0aWMgYXJ0aXN0IiwiYWxidW1OYW1lIjoiU3ludGhldGljIGFsYnVtIiwidHJhY2tVcmkiOiJzcG90aWZ5OnRyYWNrOkFBQUFBQUFBQUFBQUFBQUFBQUFBQUEifSwiZXBpc29kZSI6bnVsbCwiYXVkaW9ib29rIjpudWxsLCJsb2NhbFRyYWNrIjpudWxsLCJhZGRlZERhdGUiOiIyMDI2LTA5LTAxIn0sbnVsbCx7InRyYWNrIjp7InRyYWNrTmFtZSI6IlN5bnRoZXRpYyBmaXJzdCIsImFydGlzdE5hbWUiOiJTeW50aGV0aWMgYXJ0aXN0IiwiYWxidW1OYW1lIjoiU3ludGhldGljIGFsYnVtIiwidHJhY2tVcmkiOiJzcG90aWZ5OnRyYWNrOkFBQUFBQUFBQUFBQUFBQUFBQUFBQUEifSwiZXBpc29kZSI6bnVsbCwiYXVkaW9ib29rIjpudWxsLCJsb2NhbFRyYWNrIjpudWxsLCJhZGRlZERhdGUiOiIyMDI2LTA5LTAxIn1dfV19UEsBAhQAFAAAAAAAAABBXYijlx0pAgAAKQIAAA4AAAAAAAAAAAAAAICBAAAAAFBsYXlsaXN0MS5qc29uUEsFBgAAAAABAAEAPAAAAFUCAAAAAA==');
    final preview = await SpotifyZipImporter.parseBytes(archive, fileName: 'synthetic-account.zip');
    expect(preview.sourceEntryName, 'Playlist1.json');
    expect(preview.format, 'Spotify account playlists in ZIP');
    expect(preview.sourcePlaylists.single.members.map((member) => member.sourceRow), [1, null, 1]);
    expect(preview.tracks, hasLength(1)); expect(preview.rejectedRows, hasLength(1));
  });

  for (final variant in [
    'episode',
    'audiobook',
    'localTrack',
    'futureVariant',
  ]) {
    test('$variant and ambiguous mixed items remain unsupported slots', () {
      final value = fixture();
      items(value)[0][variant] = {};
      final preview = parse(value);
      expect(preview.sourcePlaylists.first.members.first.sourceRow, isNull);
      expect(preview.sourcePlaylists.first.members.first.issue, isNotNull);
      expect(preview.totalDataRows, 5);
      expect(preview.rejectedRows, hasLength(2));
      expect(preview.tracks.map((track) => track.sourceRow), [3, 4]);
    });
  }
  for (final malformed in [
    null,
    7,
    <String, dynamic>{},
    {'track': null},
    {
      'track': {'trackName': 'Incomplete'},
    },
    {
      'track': {
        'trackName': 'Bad URI',
        'artistName': 'Synthetic',
        'trackUri': 'spotify:local:unverified',
      },
    },
  ]) {
    test(
      'malformed account item retains its exact source position: $malformed',
      () {
        final value = fixture();
        items(value)[0] = malformed;
        final preview = parse(value);
        expect(
          preview.sourcePlaylists.first.members.map(
            (member) => member.position,
          ),
          [1, 2, 3, 4],
        );
        expect(preview.sourcePlaylists.first.members.first.sourceRow, isNull);
        expect(preview.tracks.map((track) => track.sourceRow), [3, 4]);
      },
    );
  }
  test(
    'same URI conflicting metadata rejects rather than choosing one identity',
    () {
      final value = fixture();
      items(value).last['track']['artistName'] = 'Conflicting synthetic artist';
      expect(() => parse(value), rejected);
    },
  );
  for (final conflicting in ['id', 'uri', 'tracks']) {
    test(
      'unverified account playlist $conflicting cannot be dropped to invent source identity',
      () {
        final value = fixture();
        sources(value).first[conflicting] = 'unverified';
        expect(() => parse(value), rejected);
      },
    );
  }
  test(
    'unknown track identity fields reject instead of ignoring possible conflicts',
    () {
      final value = fixture();
      items(value).first['track']['id'] = 'B' * 22;
      expect(() => parse(value), rejected);
    },
  );
  test('legacy backup tracks keep their previously accepted extra metadata', () {
    final preview = parse({'playlists': [{'name': 'Legacy synthetic', 'lastModifiedDate': '2026-10-01', 'tracks': [
      {'track': {'uri': 'spotify:track:${'A' * 22}', 'name': 'Legacy song', 'artists': [{'name': 'Synthetic'}]}},
    ]}]});
    expect(preview.format, 'Named Spotify playlist backup'); expect(preview.tracks, hasLength(1));
  });
  test(
    'account and backup shapes cannot mix across sources or root fields',
    () {
      final value = fixture();
      sources(value).add({'name': 'Mixed', 'tracks': []});
      expect(() => parse(value), rejected);
      final root = fixture()..['albums'] = [];
      expect(() => parse(root), rejected);
    },
  );
  test(
    'unsupported-only is never an empty import, while genuinely empty is explicit',
    () {
      final value = fixture();
      value['playlists'] = [
        {
          'name': 'Unsupported',
          'lastModifiedDate': '2026-10-01',
          'items': [null],
        },
      ];
      expect(() => parse(value), rejected);
      sources(value).first['items'] = [];
      final preview = parse(value);
      expect(preview.tracks, isEmpty);
      expect(preview.totalDataRows, 0);
    },
  );
  test(
    'playlist and total membership limits include unsupported slots before translation',
    () {
      final value = fixture();
      value['playlists'] = List.generate(
        201,
        (index) => {
          'name': 'Synthetic $index',
          'lastModifiedDate': '2026-10-01',
          'items': [],
        },
      );
      expect(() => parse(value), rejected);
      value['playlists'] = [
        {
          'name': 'Bounded',
          'lastModifiedDate': '2026-10-01',
          'items': List.filled(10001, null),
        },
      ];
      expect(() => parse(value), rejected);
      sources(value).first['items'] = [
        items(fixture()).first,
        ...List.filled(9999, null),
      ];
      final preview = parse(value);
      expect(preview.totalDataRows, 10000);
      expect(preview.rejectedRows, hasLength(9999));
    },
  );
  test('missing structural fields and malformed JSON reject', () {
    for (final key in ['name', 'items', 'lastModifiedDate']) {
      final value = fixture();
      sources(value).first.remove(key);
      expect(() => parse(value), rejected);
    }
    expect(
      () => SpotifySongListImporter.parseBytes(
        Uint8List.fromList(utf8.encode('{"playlists":[')),
        fileName: 'Playlist.json',
      ),
      rejected,
    );
  });

  group('existing saved-state contract', () {
    late Directory root;
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(initPriorityReviewTestPlugins);
    setUp(() async {
      root = await Directory.systemTemp.createTemp('account-playlist-');
      Hive.init(root.path);
      await initPriorityReviewHive();
      resetPriorityReviewGlobals();
      await Hive.box('user').put('ownerSentinel', {
        'ordered': [3, 1, 2],
      });
    });
    tearDown(() async {
      await Hive.close();
      await root.delete(recursive: true);
    });
    Future<void> reopen(String path) async {
      await Hive.close();
      Hive.init(path);
      await initPriorityReviewHive();
    }

    Object? copy(Object? value) => jsonDecode(jsonEncode(value));

    test(
      'explicit save, reopen and saved-file independent restore retain account membership',
      () async {
        final beforePreview = copy(Hive.box('user').toMap());
        final preview = parse(fixture());
        expect(Hive.box('user').toMap(), beforePreview);
        await const SpotifyImportSessionService().saveNewImport(
          preview,
          importedAt: DateTime.utc(2026, 10, 15),
        );
        final service = SpotifyImportDestinationService();
      final first = await service.loadSourcePlaylistSnapshot(1);
      final last = await service.loadSourcePlaylistSnapshot(3);
      expect(first.sourcePlaylistKey, isNot(last.sourcePlaylistKey));
      expect(first.sourcePlaylistKey, isNotNull); expect(last.sourcePlaylistKey, isNotNull);
      final before = copy(Hive.box('user').toMap());
        await reopen(root.path);
        expect(Hive.box('user').toMap(), before);
        final box = Hive.box('user');
        final metadata = box.get('spotifyImportMetadata') as Map;
        expect(
          SpotifySourcePlaylistCodec.readSaved(
            metadata['sourcePlaylists'],
            box.get('spotifyImportTracks'),
          ).first.members.map((member) => member.sourceRow),
          [1, null, 3, 1],
        );
        await box.flush();
        await Hive.box('settings').flush();
        final bundle = await MusifyBackupService.createBundleBytesForTesting({
          'user': await File('${root.path}/user.hive').readAsBytes(),
          'settings': await File('${root.path}/settings.hive').readAsBytes(),
        });
        final saved = File('${root.path}/synthetic-account.musifybackup');
        await saved.writeAsBytes(bundle, flush: true);
        final inspected = await MusifyBackupService.inspectBundleFileForTesting(
          saved,
        );
        final independent = await Directory(
          '${root.path}/independent',
        ).create();
        await reopen(independent.path);
        expect(
          (await MusifyBackupService.restoreValidatedBackup(inspected)).success,
          isTrue,
        );
        await reopen(independent.path);
        expect(Hive.box('user').toMap(), before);
      },
    );
    test(
      'partial save failure restores previous legacy keys and survives reopen',
      () async {
        await Hive.box('user').putAll({
          'spotifyImportTracks': [
            {'legacy': true},
          ],
          'spotifyImportMetadata': {'partialLegacy': true},
        });
        final before = copy(Hive.box('user').toMap());
        final service = SpotifyImportSessionService(
          sessionWriter: (box, values) async {
            await box.put('spotifyImportTracks', values['spotifyImportTracks']);
            throw StateError('Injected account save interruption');
          },
        );
        await expectLater(
          service.saveNewImport(parse(fixture())),
          throwsStateError,
        );
        expect(Hive.box('user').toMap(), before);
        await reopen(root.path);
        expect(Hive.box('user').toMap(), before);
      },
    );
  });
}
