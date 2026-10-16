import 'dart:convert';
import 'dart:typed_data';

class SpotifyPlaylistFixture {
  static Map<String, dynamic> song(String id, {bool local = false}) => {
    'track': {
      'uri': 'spotify:track:$id',
      'name': id.startsWith('A') ? 'First' : 'Second',
      'artists': [
        {'name': 'Owner'},
      ],
      'album': {'name': 'Owned album'},
      'type': 'track',
      'is_local': local,
    },
    'added_at': '2026-10-01T12:00:00Z',
  };
  static Uint8List bytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'playlists': [
          {
            'name': 'One',
            'tracks': [song('A' * 22), null, song('A' * 22)],
          },
          {
            'name': 'Two',
            'tracks': [song('B' * 22), song('L' * 22, local: true)],
          },
          {'name': 'Empty', 'tracks': []},
        ],
        'albums': [],
      }),
    ),
  );
}
