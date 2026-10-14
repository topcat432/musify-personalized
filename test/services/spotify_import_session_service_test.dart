import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_zip_archive.dart';
import '../support/spotify_zip_fixtures.dart';

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

  for (final prior in [
    <String, dynamic>{'fileName': 'legacy.csv'},
    <String, dynamic>{'fileName': 'old.zip', 'sourceEntryName': 'old.csv'},
  ]) {
    test(
      'entry provenance rollback, old state and restart ${prior['fileName']}',
      () async {
        final box = Hive.box('user');
        await box.putAll({
          'spotifyImportMetadata': prior,
          'likedSongs': ['keep'],
        });
        final before = jsonDecode(jsonEncode(box.toMap()));
        final preview = await SpotifyZipArchive.inspect(
          SpotifyZipFixtures.selectedLists(),
        ).parseEntry('second.tsv', fileName: 'account.zip');
        await expectLater(
          SpotifyImportSessionService(
            sessionWriter: (target, values) async {
              await target.putAll(values);
              throw StateError('Owned partial write');
            },
          ).saveNewImport(preview),
          throwsStateError,
        );
        expect(box.toMap(), before);
        await Hive.close();
        await Hive.openBox('user');
        expect(Hive.box('user').toMap(), before);
        await const SpotifyImportSessionService().saveNewImport(preview);
        await Hive.close();
        await Hive.openBox('user');
        expect(
          Hive.box('user').get('spotifyImportMetadata')['sourceEntryName'],
          'second.tsv',
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
            'sourceEntryName',
          ),
          isFalse,
        );
      },
    );
  }

  for (final failFirst in [false, true]) {
    test(
      'overlapping imports reject the second writer while the first ${failFirst ? 'rolls back' : 'commits'}',
      () async {
        final box = Hive.box('user');
        await box.put('spotifyImportMetadata', {'fileName': 'original.csv'});
        final pending = Completer<void>();
        final started = Completer<void>();
        SpotifyImportPreview preview(String name) =>
            SpotifyCsvImporter.parseBytes(
              Uint8List.fromList(
                utf8.encode('title,artist\n$name,Owned fixture\n'),
              ),
              fileName: '$name.csv',
            );
        final first = SpotifyImportSessionService(
          sessionWriter: (target, values) async {
            await target.putAll(values);
            started.complete();
            await pending.future;
            if (failFirst)
              throw const FileSystemException('Owned delayed write failure');
          },
        );
        final operation = first.saveNewImport(preview('A'));
        try {
          await started.future;
          await expectLater(
            const SpotifyImportSessionService().saveNewImport(preview('B')),
            throwsStateError,
          );
          expect(
            (box.get('spotifyImportMetadata') as Map)['fileName'],
            'A.csv',
          );
        } finally {
          pending.complete();
          await expectLater(
            operation,
            failFirst ? throwsA(isA<FileSystemException>()) : completes,
          );
        }
        expect(
          (box.get('spotifyImportMetadata') as Map)['fileName'],
          failFirst ? 'original.csv' : 'A.csv',
        );
        await const SpotifyImportSessionService().saveNewImport(preview('B'));
        await Hive.close();
        await Hive.openBox('user');
        expect(
          (Hive.box('user').get('spotifyImportMetadata') as Map)['fileName'],
          'B.csv',
        );
        expect(
          ((Hive.box('user').get('spotifyImportTracks') as List).single
              as Map)['title'],
          'B',
        );
      },
    );
  }

  test(
    'a new import removes every result and route from the old import',
    () async {
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
    },
  );

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
        await target.put('spotifyImportTracks', values['spotifyImportTracks']);
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
