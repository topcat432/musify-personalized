import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';

void main() {
  Uint8List csvBytes(String value) => Uint8List.fromList(utf8.encode(value));

  group('SpotifyCsvImporter', () {
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
      const csv = '''Track URI,Track Name,Artist Name(s),Album Name,Track Duration (ms),Added At
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
      const csv = 'title,artist,album,isrc\n"A ""Quoted""\nSong",Artist,Album,ABC\n';

      final preview = SpotifyCsvImporter.parseBytes(
        csvBytes(csv),
        fileName: 'quoted.csv',
      );

      expect(preview.tracks.single.title, 'A "Quoted"\nSong');
    });

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
