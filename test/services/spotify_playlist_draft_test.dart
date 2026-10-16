import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_playlist_draft.dart';

void main() {
  Map<String, dynamic> song(String id, {String name = 'First'}) => {
    'track': {
      'uri': 'spotify:track:$id',
      'name': name,
      'artists': [
        {'name': 'Owner'},
      ],
      'album': {'name': 'Owned album'},
      'duration_ms': 70000,
      'type': 'track',
    },
  };
  final a = song('A' * 22), b = song('B' * 22);
  Uint8List bytes(Object document) =>
      Uint8List.fromList(utf8.encode(jsonEncode(document)));
  final rejected = throwsA(isA<SpotifyImportException>());
  test(
    'supplied playlist identity conflict cannot silently share a source scope',
    () {
      final uri = 'spotify:playlist:${'P' * 22}';
      expect(
        () => SpotifyPlaylistDraft.parseBytes(
          bytes({
            'playlists': [
              {
                'name': 'Same',
                'uri': uri,
                'id': 'Q' * 22,
                'tracks': [a],
              },
            ],
          }),
        ),
        rejected,
      );
      expect(
        SpotifyPlaylistDraft.parseBytes(
          bytes({
            'playlists': [
              {
                'name': 'Same',
                'uri': uri,
                'id': 'P' * 22,
                'tracks': [a],
              },
            ],
          }),
        ).playlists.single.spotifyUri,
        uri,
      );
    },
  );

  test(
    'unique recording matched once with ordered repeated playlist membership',
    () {
      final draft = SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {
              'name': 'One',
              'uri': 'spotify:playlist:${'P' * 22}',
              'tracks': [a, null, b, a],
            },
            {
              'name': 'One',
              'tracks': [b, a],
            },
          ],
          'albums': [
            {'ignored': 'album'},
          ],
        }),
      );
      expect(draft.tracks.map((t) => t.spotifyTrackId), ['A' * 22, 'B' * 22]);
      expect(draft.tracks.map((t) => t.sourceRow), [1, 3]);
      expect(draft.playlists.map((p) => p.name), ['One', 'One']);
      expect(draft.playlists.first.members.map((m) => m.position), [
        1,
        2,
        3,
        4,
      ]);
      expect(draft.playlists.first.members.map((m) => m.sourceRow), [
        1,
        null,
        3,
        1,
      ]);
      expect(draft.playlists.last.members.map((m) => m.sourceRow), [3, 1]);
      expect(draft.ignoredAlbums, 1);
      expect(() => draft.tracks.clear(), throwsUnsupportedError);
      expect(
        () => draft.playlists.first.members.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('same title with distinct recording identities stays distinct', () {
    final draft = SpotifyPlaylistDraft.parseBytes(
      bytes({
        'playlists': [
          {
            'name': 'One',
            'tracks': [a, b],
          },
        ],
      }),
    );
    expect(draft.tracks, hasLength(2));
  });
  test(
    'missing local episode and malformed songs keep membership positions',
    () {
      final local = song('L' * 22);
      local['added_at'] = '2026-10-01T12:00:00Z';
      (local['track'] as Map)['is_local'] = true;
      final episode = song('E' * 22);
      (episode['track'] as Map)['type'] = 'episode';
      final draft = SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {
              'name': 'One',
              'tracks': [
                null,
                local,
                episode,
                {
                  'track': {'name': 'No URI'},
                },
                a,
              ],
            },
            {'name': 'Empty', 'tracks': []},
          ],
        }),
      );
      expect(draft.playlists.first.members.map((m) => m.position), [
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(
        draft.playlists.first.members
            .take(4)
            .every((m) => m.issue != null && m.sourceRow == null),
        isTrue,
      );
      expect(draft.tracks.single.sourceRow, 5);
      expect(draft.playlists.first.members[1].sourceMetadata['title'], 'First');
      expect(
        draft.playlists.first.members[1].sourceMetadata['addedAt'],
        '2026-10-01T12:00:00Z',
      );
      expect(
        () => draft.playlists.first.members[1].sourceMetadata.clear(),
        throwsUnsupportedError,
      );
      expect(draft.playlists.last.members, isEmpty);
    },
  );
  test(
    'same-URI comma-joined artist collision rejects structurally distinct lists',
    () {
      final one = song('C' * 22);
      (one['track'] as Map)['artists'] = [
        {'name': 'Earth, Wind & Fire'},
      ];
      final two = song('C' * 22);
      (two['track'] as Map)['artists'] = [
        {'name': 'Earth'},
        {'name': 'Wind & Fire'},
      ];
      final oneOnly = SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {
              'name': 'One',
              'tracks': [one],
            },
          ],
        }),
      );
      expect(oneOnly.tracks.single.artist, 'Earth, Wind & Fire');
      expect(
        () => SpotifyPlaylistDraft.parseBytes(
          bytes({
            'playlists': [
              {
                'name': 'One',
                'tracks': [one, two],
              },
            ],
          }),
        ),
        rejected,
      );
      final same = song('C' * 22);
      (same['track'] as Map)['artists'] = [
        {'name': ' Earth, Wind & Fire '},
      ];
      expect(
        SpotifyPlaylistDraft.parseBytes(
          bytes({
            'playlists': [
              {
                'name': 'One',
                'tracks': [one, same],
              },
            ],
          }),
        ).tracks,
        hasLength(1),
      );
    },
  );
  test('nested explicit ID mismatch retains unsupported member position', () {
    final mismatch = song('A' * 22);
    (mismatch['track'] as Map)['id'] = 'B' * 22;
    final good = song('A' * 22);
    (good['track'] as Map)['id'] = 'A' * 22;
    final draft = SpotifyPlaylistDraft.parseBytes(
      bytes({
        'playlists': [
          {
            'name': 'One',
            'tracks': [mismatch, good, song('C' * 22)],
          },
        ],
      }),
    );
    expect(draft.playlists.single.members.map((m) => m.position), [1, 2, 3]);
    expect(draft.playlists.single.members.first.sourceRow, isNull);
    expect(
      draft.playlists.single.members.first.issue,
      'Conflicting Spotify track ID and URI',
    );
    expect(draft.tracks.map((t) => t.sourceRow), [2, 3]);
    expect(draft.tracks.first.spotifyTrackId, 'A' * 22);
  });
  test('conflicting same-URI metadata fails without merging recordings', () {
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {
              'name': 'One',
              'tracks': [a, song('A' * 22, name: 'Different')],
            },
          ],
        }),
      ),
      rejected,
    );
  });
  for (final input in [
    <String, dynamic>{'tracks': []},
    <String, dynamic>{'playlists': []},
    <String, dynamic>{
      'playlists': [
        {'name': '', 'tracks': []},
      ],
    },
    <String, dynamic>{
      'playlists': [
        {'name': 'One', 'tracks': {}},
      ],
    },
    <String, dynamic>{
      'playlists': [
        {'name': 'One', 'tracks': []},
      ],
      'albums': {},
    },
    <String, dynamic>{
      'playlists': [
        {'name': 'One', 'uri': 'https://untrusted.invalid', 'tracks': []},
      ],
    },
  ]) {
    test('wrong envelope rejects ${jsonEncode(input)}', () {
      expect(() => SpotifyPlaylistDraft.parseBytes(bytes(input)), rejected);
    });
  }
  test('playlist and total membership limits reject before models', () {
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': List.filled(201, {'name': 'One', 'tracks': []}),
        }),
      ),
      rejected,
    );
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {'name': 'One', 'tracks': List.filled(10001, null)},
          ],
        }),
      ),
      rejected,
    );
    expect(
      SpotifyPlaylistDraft.parseBytes(
        bytes({
          'playlists': [
            {'name': 'One', 'tracks': List.filled(10000, null)},
          ],
        }),
      ).playlists.single.members,
      hasLength(10000),
    );
  });
  test('bounded envelope retains duplicate key, UTF8 and depth rejection', () {
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        Uint8List.fromList(
          utf8.encode('{"playlists":[],"playl\\u0069sts":[]}'),
        ),
      ),
      rejected,
    );
    expect(
      () => SpotifyPlaylistDraft.parseBytes(Uint8List.fromList([255])),
      rejected,
    );
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        Uint8List.fromList(utf8.encode('[' * 25 + '0' + ']' * 25)),
      ),
      rejected,
    );
    expect(
      () => SpotifyPlaylistDraft.parseBytes(
        Uint8List(SpotifyCsvImporter.maxJsonBytes + 1),
      ),
      rejected,
    );
  });
}
