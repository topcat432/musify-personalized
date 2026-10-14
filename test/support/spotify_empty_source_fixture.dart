import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/services/spotify_playlist_draft.dart';
import 'package:musify/services/spotify_csv_importer.dart';

class SpotifyEmptySourceFixture {
  static SpotifyImportPreview preview({bool song = true, bool unsupported = false, bool uri = true}) =>
      SpotifyPlaylistDraft.parseBytes(Uint8List.fromList(utf8.encode(jsonEncode({
        'playlists': [
          {'name': 'Owned empty', if (uri) 'uri': 'spotify:playlist:aaaaaaaaaaaaaaaaaaaaaa', 'tracks': []},
          if (song || unsupported) {'name':'Owned other', 'tracks':[
            if (song) {'track':{'uri':'spotify:track:bbbbbbbbbbbbbbbbbbbbbb','name':'Owned song','artists':[{'name':'Owned artist'}]}},
            if (unsupported) {'track':{'type':'episode','name':'Owned unsupported'}},
          ]},
        ],
      })))).toPreview(fileName:'owned-empty.json');
  static Future<void> seed({bool song = true, bool unsupported = false, bool uri = true}) async {
    await const SpotifyImportSessionService().saveNewImport(preview(song:song,unsupported:unsupported,uri:uri),importedAt:DateTime.utc(2026,10,14));
    await Hive.box('user').putAll({
      'likedSongs':[{'ytid':'keep-owner'}],
      'customPlaylists':[{'ytid':'customId-keep','title':'Keep','source':'user-created','list':[{'ytid':'keep-song'}]}],
      if(song) 'spotifyMatchResults':[{'sourceRow':1,'status':'matched','bestCandidate':{'ytid':'owned-choice','title':'Owned chosen recording'}}],
      'ownedSentinel': {'order':[3,1,2]},
    });
  }
}