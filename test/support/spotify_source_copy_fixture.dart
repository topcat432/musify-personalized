import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_playlist_draft.dart';

class SpotifySourceCopyFixture {
  static const expectedIds = ['chosen-alternative-A', 'chosen-B', 'chosen-alternative-A'];
  static Future<void> seed() async {
    final preview = SpotifyPlaylistDraft.parseBytes(Uint8List.fromList(utf8.encode(jsonEncode({
      'playlists': [{'name': 'Synthetic source order', 'uri': 'spotify:playlist:${'P' * 22}',
        'tracks': [for (final id in ['A', 'B', 'A']) {'track': {
          'uri': 'spotify:track:${id * 22}', 'name': 'Synthetic $id',
          'artists': [{'name': 'Synthetic source artist'}], 'album': {'name': 'Synthetic album'},
        }}]}],
    })))).toPreview(fileName: 'synthetic-copy.json');
    await const SpotifyImportSessionService().saveNewImport(preview, importedAt: DateTime.utc(2026, 10, 15));
    await Hive.box('user').putAll({
      'spotifyMatchResults': [for (final (index, id) in ['A', 'B'].indexed)
        {'sourceRow': index + 1, 'status': 'manually_matched', 'bestCandidate': {
          'ytid': index == 0 ? expectedIds[0] : expectedIds[1],
          'title': 'Selected alternative $id', 'artist': 'Synthetic owner choice',
          'duration': 70000, 'nested': {'keep': [3, 1, 2]},
        }}],
      'customPlaylists': [{'ytid': 'customId-owner', 'title': 'Owner root', 'source': 'user-created',
        'list': [{'ytid': 'owner-recording'}], 'typed': Uint8List.fromList([3, 1, 2]), 'at': DateTime.utc(2026)}],
      'playlistFolders': [{'id': 'owner-folder', 'name': 'Owner folder', 'opaque': true,
        'playlists': [{'ytid': 'customId-folder-owner', 'source': 'user-created', 'title': 'Owner nested',
          'list': [{'ytid': 'nested-owner-recording'}]}]}],
      'playlists': ['owner-youtube'], 'likedSongs': [{'ytid': 'liked-owner'}],
      'pinnedPlaylistIds': ['customId-owner'], 'ownerSentinel': {'order': [3, 1, 2]},
    });
    hydrate();
  }
  static void hydrate() {
    final box = Hive.box('user');
    userCustomPlaylists.value = List<Map>.from(box.get('customPlaylists', defaultValue: const []));
    userPlaylistFolders.value = List<Map>.from(box.get('playlistFolders', defaultValue: const []));
    userPlaylists.value = List<String>.from(box.get('playlists', defaultValue: const []));
  }
}
