import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';

void main() {
  Uint8List csvBytes(String value) => Uint8List.fromList(utf8.encode(value));

  group('SpotifyCsvImporter', () {
    test(
      'optional row budget preserves quoted records and interior positions',
      () {
        final preview = SpotifyCsvImporter.parseBytes(
          csvBytes(
            'Title,Artist\r\n"First\npart",Owner\r\n,\r\nSecond,Owner\r\n,\r\n\r\n',
          ),
          fileName: 'owned.csv',
          maxDataRows: 3,
        );
        expect(preview.tracks.map((track) => track.title), [
          'First\npart',
          'Second',
        ]);
        expect(preview.tracks.map((track) => track.sourceRow), [2, 4]);
        expect(preview.totalDataRows, 3);
      },
    );
    test('direct CSV remains unrestricted and visits a malformed tail', () {
      final records = 'Title,Artist\n' + List.filled(10001, 'A,B\n').join();
      expect(
        SpotifyCsvImporter.parseBytes(
          csvBytes(records),
          fileName: 'owned.csv',
        ).tracks.length,
        10001,
      );
      expect(
        () => SpotifyCsvImporter.parseBytes(
          csvBytes('$records"unterminated'),
          fileName: 'owned.csv',
        ),
        throwsA(
          isA<SpotifyImportException>().having(
            (e) => e.message,
            'malformed tail',
            contains('unterminated'),
          ),
        ),
      );
    });
    test('parses Soundiiz CSV with quoted artists', () {
      const csv = '''index,title,artist,album,isrc
0,THE 1,"Rell Moore, Saint Meadow",THE 1 (MIXTAPE),QZTAZ2464735
1,Like That,"Future, Metro Boomin, Kendrick Lamar",WE DON'T TRUST YOU,USSM12402041
''';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'liked.csv',
      );

      expect(preview.format, 'Soundiiz');
      expect(preview.tracks, hasLength(2));
      expect(preview.tracks.first.artist, 'Rell Moore, Saint Meadow');
      expect(preview.tracks.last.isrc, 'USSM12402041');
      expect(preview.rejectedRows, isEmpty);
    });

    test('parses Exportify columns and duration', () {
      const csv =
          '''Track URI,Track Name,Artist Name(s),Album Name,Track Duration (ms),Added At
spotify:track:1,"Song, One",Artist One,Album One,147520,2015-08-04T04:07:20Z
''';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'exportify.csv',
      );

      expect(preview.format, 'Spotify/Exportify');
      expect(preview.tracks.single.title, 'Song, One');
      expect(preview.tracks.single.durationMs, 147520);
      expect(
        preview.tracks.single.addedAt,
        DateTime.parse('2015-08-04T04:07:20Z'),
      );
    });

    test('preserves short durations from an explicit millisecond column', () {
      const csv = '''Track Name,Artist Name(s),Track Duration (ms)
Short Intro,Example Artist,8000
''';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'short-exportify.csv',
      );

      expect(preview.tracks.single.durationMs, 8000);
    });

    test('converts short values from an ambiguous duration column', () {
      const csv = '''title,artist,duration
Short Intro,Example Artist,8
''';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'generic.csv',
      );

      expect(preview.tracks.single.durationMs, 8000);
    });

    test('rejects rows that are missing required values', () {
      const csv = '''index,title,artist,album,isrc
0,Valid Song,Valid Artist,Album,ABC
1,,Missing Title Artist,Album,DEF
2,Missing Artist,,Album,GHI
''';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'liked.csv',
      );

      expect(preview.tracks, hasLength(1));
      expect(preview.rejectedRows, hasLength(2));
      expect(preview.rejectedRows.first.sourceRow, 3);
    });

    test('supports escaped quotes and newlines inside quoted fields', () {
      const csv =
          'title,artist,album,isrc\n"A ""Quoted""\nSong",Artist,Album,ABC\n';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'quoted.csv',
      );

      expect(preview.tracks.single.title, 'A "Quoted"\nSong');
    });

    test('TSV preserves metadata, rejected row positions and source order', () {
      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(
          '\ufeffTrack URI\tTrack Name\tArtist Name(s)\tAlbum Name\tTrack Duration (ms)\tAdded At\r\n'
          'spotify:track:AAAAAAAAAAAAAAAAAAAAAA\tFirst, original\tOwned artist\tOwned album\t8500\t2026-01-01T12:00:00Z\r\n'
          '\t\tMissing title\t\t\t\r\n'
          'spotify:track:BBBBBBBBBBBBBBBBBBBBBB\tSecond\tOther artist\t\t9100\t\r\n',
        ),
        fileName: 'owned.TSV',
      );
      expect(preview.format, 'Spotify/Exportify TSV');
      expect(preview.fileName, 'owned.TSV');
      expect(preview.totalDataRows, 3);
      expect(preview.tracks.map((t) => t.sourceRow), [2, 4]);
      expect(preview.tracks.map((t) => t.title), ['First, original', 'Second']);
      expect(preview.tracks.first.durationMs, 8500);
      expect(preview.tracks.first.spotifyTrackId, 'AAAAAAAAAAAAAAAAAAAAAA');
      expect(preview.tracks.first.addedAt, DateTime.utc(2026, 1, 1, 12));
      expect(preview.rejectedRows.single.sourceRow, 3);
    });

    test('TSV supports quoted tabs, newlines, commas and escaped quotes', () {
      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(
          'title\tartist\talbum\r\n"A\t""Quoted""\nSong"\tArtist\t"Album, original"\r\n',
        ),
        fileName: 'quoted.tsv',
      );
      expect(preview.format, 'Generic music TSV');
      expect(preview.tracks.single.title, 'A\t"Quoted"\nSong');
      expect(preview.tracks.single.album, 'Album, original');
    });

    test(
      'TSV refuses playlist membership instead of silently flattening it',
      () {
        expect(
          () => SpotifyCsvImporter.parseBytes(
            csvBytes(
              'title\tartist\tplaylist name\nOwned\tArtist\tPlaylist A\n',
            ),
            fileName: 'playlist.tsv',
          ),
          throwsA(
            isA<SpotifyImportException>().having(
              (e) => e.message,
              'message',
              contains('playlist membership'),
            ),
          ),
        );
      },
    );

    test('CSV keeps literal tabs rather than silently changing delimiters', () {
      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes('title,artist\n"Owned\tTitle",Artist\n'),
        fileName: 'literal-tab.csv',
      );
      expect(preview.format, 'Generic music CSV');
      expect(preview.tracks.single.title, 'Owned\tTitle');
    });

    for (final (label, contents) in [
      ('missing columns', 'album\tgenre\nOwned\tRock\n'),
      ('unterminated quote', 'title\tartist\n"Unfinished\tArtist\n'),
      ('no valid songs', 'title\tartist\n\tArtist\n'),
      ('wrong delimiter', 'title,artist\nWrong delimiter,Artist\n'),
    ]) {
      test('rejects unsupported or malformed TSV $label', () {
        expect(
          () => SpotifyCsvImporter.parseBytes(
            csvBytes(contents),
            fileName: 'invalid.tsv',
          ),
          throwsA(isA<SpotifyImportException>()),
        );
      });
    }

    test('fails clearly when required columns are missing', () {
      const csv = 'album,isrc\nAlbum,ABC\n';

      expect(
        () => SpotifyCsvImporter.parseBytes(
          csvBytes(csv),
          fileName: 'invalid.csv',
        ),
        throwsA(isA<SpotifyImportException>()),
      );
    });
  });
}
