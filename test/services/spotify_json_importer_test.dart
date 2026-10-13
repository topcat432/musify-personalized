import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';

void main() {
  Uint8List encoded(Object? value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));
  SpotifyImportPreview parse(Object? value) => SpotifyCsvImporter.parseBytes(
    encoded(value),
    fileName: 'YourLibrary.json',
  );
  Map<String, Object?> track(String title, {String? uri}) => {
    'artist': 'Owned artist',
    'track': title,
    'album': 'Owned album',
    if (uri != null) 'uri': uri,
  };

  test('saved-track JSON preserves Unicode, order, positions and identity', () {
    final result = parse({
      'tracks': [
        track(
          'First \u2014 \u539f\u66f2',
          uri: 'spotify:track:AAAAAAAAAAAAAAAAAAAAAA',
        ),
        track('Second'),
      ],
    });
    expect(result.format, 'Spotify saved tracks JSON');
    expect(result.fileName, 'YourLibrary.json');
    expect(result.totalDataRows, 2);
    expect(result.tracks.map((t) => t.title), [
      'First \u2014 \u539f\u66f2',
      'Second',
    ]);
    expect(result.tracks.map((t) => t.sourceRow), [1, 2]);
    expect(result.tracks.first.spotifyTrackId, 'AAAAAAAAAAAAAAAAAAAAAA');
    expect(result.tracks.first.durationMs, isNull);
    expect(result.tracks.first.addedAt, isNull);
    expect(result.tracks.last.spotifyTrackUri, isNull);
  });

  test('other library entities and bans are disclosed without flattening', () {
    final result = parse({
      'tracks': [track('Saved song')],
      'albums': [{}],
      'artists': [{}, {}],
      'bannedTracks': [{}],
      'shows': [],
      'episodes': [],
      'other': [],
      'bannedArtists': [],
    });
    expect(result.tracks, hasLength(1));
    expect(result.notices, contains('Albums: 1 entry not imported.'));
    expect(result.notices, contains('Artists: 2 entries not imported.'));
    expect(result.notices.first, contains('blocked-item preferences'));
  });

  test('invalid entries retain explicit rejected positions', () {
    final result = parse({
      'tracks': [
        null,
        {'track': 'Missing artist'},
        track('Wrong URI', uri: 'spotify:episode:AAAAAAAAAAAAAAAAAAAAAA'),
        {...track('Wrong album'), 'album': {}},
        {...track('Membership'), 'playlistName': 'Owned list'},
        track('Valid'),
      ],
    });
    expect(result.totalDataRows, 6);
    expect(result.tracks.single.sourceRow, 6);
    expect(result.rejectedRows.map((r) => r.sourceRow), [1, 2, 3, 4, 5]);
    expect(result.rejectedRows[2].reason, contains('track URI'));
  });

  test('BOM and uppercase extension are accepted', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        '\ufeff${jsonEncode({
          'tracks': [track('Owned')],
        })}',
      ),
    );
    expect(
      SpotifyCsvImporter.parseBytes(
        bytes,
        fileName: 'owned.JSON',
      ).tracks.single.title,
      'Owned',
    );
  });

  test('quoted brackets and escaped quotes do not count as depth', () {
    final title = '${'[' * 100} "Owned"';
    expect(
      parse({
        'tracks': [track(title)],
      }).tracks.single.title,
      title,
    );
  });

  for (final (label, value) in [
    ('playlist document', {'playlists': []}),
    (
      'unknown root fields',
      {
        'tracks': [track('Owned')],
        'profile': {},
      },
    ),
    ('wrong track container', {'tracks': {}}),
    (
      'wrong section container',
      {
        'tracks': [track('Owned')],
        'albums': 'wrong',
      },
    ),
    ('empty tracks', {'tracks': []}),
    ('non-object root', []),
  ]) {
    test('rejects $label without guessing', () {
      expect(() => parse(value), throwsA(isA<SpotifyImportException>()));
    });
  }

  test('malformed JSON and invalid UTF-8 fail', () {
    for (final bytes in [
      Uint8List.fromList(utf8.encode('{"tracks":[')),
      Uint8List.fromList([0xc3, 0x28]),
    ]) {
      expect(
        () => SpotifyCsvImporter.parseBytes(bytes, fileName: 'owned.json'),
        throwsA(isA<SpotifyImportException>()),
      );
    }
  });

  test('byte and track limits reject', () {
    expect(
      () => SpotifyCsvImporter.parseBytes(
        Uint8List(SpotifyCsvImporter.maxJsonBytes + 1),
        fileName: 'owned.json',
      ),
      throwsA(isA<SpotifyImportException>()),
    );
    expect(
      () => parse({
        'tracks': List.filled(
          SpotifyCsvImporter.maxJsonTracks + 1,
          track('Owned'),
        ),
      }),
      throwsA(isA<SpotifyImportException>()),
    );
  });

  test('depth limit rejects before JSON decoding', () {
    final text =
        '${'[' * (SpotifyCsvImporter.maxJsonDepth + 1)}0${']' * (SpotifyCsvImporter.maxJsonDepth + 1)}';
    expect(
      () => SpotifyCsvImporter.parseBytes(
        Uint8List.fromList(utf8.encode(text)),
        fileName: 'owned.json',
      ),
      throwsA(
        isA<SpotifyImportException>().having(
          (e) => e.message,
          'message',
          contains('deeply'),
        ),
      ),
    );
  });

  test('path-like URI is not a filesystem instruction', () {
    expect(
      () => parse({
        'tracks': [track('Owned', uri: '../../outside.json')],
      }),
      throwsA(isA<SpotifyImportException>()),
    );
  });
  test(
    'duplicate root or track keys reject rather than overwrite source data',
    () {
      for (final text in [
        '{"tracks":[],"tracks":[]}',
        '{"tracks":[{"track":"One","track":"Two","artist":"Owned"}]}',
        '{"tracks":[],"tr\\u0061cks":[]}',
      ]) {
        expect(
          () => SpotifyCsvImporter.parseBytes(
            Uint8List.fromList(utf8.encode(text)),
            fileName: 'owned.json',
          ),
          throwsA(
            isA<SpotifyImportException>().having(
              (e) => e.message,
              'message',
              contains('duplicate'),
            ),
          ),
        );
      }
    },
  );
}
