import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('json-session-');
    Hive.init(root.path);
    await Hive.openBox('user');
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  test(
    'JSON partial write rolls back old session, then retry reopens exact order and identity',
    () async {
      var box = Hive.box('user');
      await box.putAll({
        'likedSongs': ['keep-liked'],
        'spotifyImportTracks': [
          {'title': 'Old'},
        ],
        'spotifyImportMetadata': {
          'fileName': 'old.csv',
          'matchingStatus': 'completed',
        },
        'spotifyMatchResults': [
          {'ytid': 'selected-old', 'status': 'accepted'},
        ],
        'spotifyExcludedImportRows': [7],
      });
      final before = Map<dynamic, dynamic>.from(box.toMap());
      final preview = SpotifyCsvImporter.parseBytes(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'tracks': [
                {
                  'track': 'First',
                  'artist': 'Owned',
                  'album': 'Owned',
                  'uri': 'spotify:track:AAAAAAAAAAAAAAAAAAAAAA',
                },
                {'track': 'Second', 'artist': 'Owned'},
              ],
            }),
          ),
        ),
        fileName: 'YourLibrary.json',
      );
      final failing = SpotifyImportSessionService(
        sessionWriter: (target, values) async {
          await target.put(
            'spotifyImportTracks',
            values['spotifyImportTracks'],
          );
          await target.put(
            'spotifyImportMetadata',
            values['spotifyImportMetadata'],
          );
          throw StateError('Owned partial write');
        },
      );
      await expectLater(failing.saveNewImport(preview), throwsStateError);
      await Hive.close();
      box = await Hive.openBox('user');
      expect(box.toMap(), before);
      await const SpotifyImportSessionService().saveNewImport(preview);
      await Hive.close();
      box = await Hive.openBox('user');
      expect((box.get('spotifyImportTracks') as List).map((t) => t['title']), [
        'First',
        'Second',
      ]);
      expect(
        (box.get('spotifyImportTracks') as List).map((t) => t['sourceRow']),
        [1, 2],
      );
      expect(
        box.get('spotifyImportTracks')[0]['spotifyTrackId'],
        'AAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(
        box.get('spotifyImportMetadata')['format'],
        'Spotify saved tracks JSON',
      );
      expect(box.get('spotifyImportMetadata')['version'], 1);
      expect(box.get('likedSongs'), ['keep-liked']);
    },
  );
}
