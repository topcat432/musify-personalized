import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';

void main() {
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('import-session-test-');
    Hive.init(hiveRoot.path);
    await Hive.openBox('user');
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  test('a new import removes every result and route from the old import', () async {
    final box = Hive.box('user');
    await box.putAll({
      'spotifyImportTracks': [
        {'sourceRow': 2, 'title': 'Old song', 'artist': 'Old artist'},
      ],
      'spotifyImportMetadata': {
        'fileName': 'old.csv',
        'matchingStatus': 'complete',
        'routingHistory': [
          {'destinationKind': 'likedSongs', 'selectedCount': 1},
        ],
      },
      'spotifyMatchResults': [
        {
          'sourceRow': 2,
          'status': 'matched',
          'bestCandidate': {'ytid': 'old-video'},
        },
      ],
      'spotifyExcludedImportRows': ['3'],
    });
    final preview = SpotifyImportPreview(
      fileName: 'new.csv',
      format: 'Generic music CSV',
      totalDataRows: 1,
      tracks: const [
        SpotifyImportTrack(
          sourceRow: 2,
          title: 'New song',
          artist: 'New artist',
          album: 'New album',
          isrc: '',
          durationMs: null,
          addedAt: null,
        ),
      ],
      rejectedRows: const [],
    );
    final importedAt = DateTime.utc(2026, 7, 14, 20);

    await const SpotifyImportSessionService().saveNewImport(
      preview,
      importedAt: importedAt,
    );

    final tracks = box.get('spotifyImportTracks') as List;
    final metadata = Map<String, dynamic>.from(
      box.get('spotifyImportMetadata') as Map,
    );
    expect((tracks.single as Map)['title'], 'New song');
    expect(box.get('spotifyMatchResults'), isEmpty);
    expect(box.get('spotifyExcludedImportRows'), isEmpty);
    expect(metadata['fileName'], 'new.csv');
    expect(metadata['matchingStatus'], 'not_started');
    expect(metadata['nextTrackIndex'], 0);
    expect(metadata['routingHistory'], isNull);
    expect(metadata['importedAt'], importedAt.toIso8601String());
    expect(metadata['importSessionId'], isNotEmpty);
  });

  test('a failed replacement restores the complete previous import', () async {
    final box = Hive.box('user');
    final oldValues = <String, dynamic>{
      'spotifyImportTracks': [
        {'sourceRow': 2, 'title': 'Old song', 'artist': 'Old artist'},
      ],
      'spotifyImportMetadata': {
        'fileName': 'old.csv',
        'matchingStatus': 'complete',
        'routingHistory': [
          {'destinationKind': 'likedSongs', 'selectedCount': 1},
        ],
      },
      'spotifyMatchResults': [
        {
          'sourceRow': 2,
          'status': 'matched',
          'bestCandidate': {'ytid': 'old-video'},
        },
      ],
      'spotifyExcludedImportRows': ['3'],
    };
    await box.putAll(oldValues);
    final preview = SpotifyImportPreview(
      fileName: 'new.csv',
      format: 'Generic music CSV',
      totalDataRows: 1,
      tracks: const [
        SpotifyImportTrack(
          sourceRow: 2,
          title: 'New song',
          artist: 'New artist',
          album: '',
          isrc: '',
          durationMs: null,
          addedAt: null,
        ),
      ],
      rejectedRows: const [],
    );
    final service = SpotifyImportSessionService(
      sessionWriter: (target, values) async {
        await target.put(
          'spotifyImportTracks',
          values['spotifyImportTracks'],
        );
        throw const FileSystemException('simulated storage failure');
      },
    );

    await expectLater(
      service.saveNewImport(preview),
      throwsA(isA<FileSystemException>()),
    );

    for (final entry in oldValues.entries) {
      expect(box.get(entry.key), entry.value, reason: entry.key);
    }
  });
}
