import 'package:musify/main.dart' show logger;
import 'package:musify/services/artist_service.dart' show ytMusicClient;
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

/// Normal Search uses the provider's song category, never a duration heuristic.
Future<List<dynamic>> searchMusicSongs(String query) async {
  try {
    final songs = await ytMusicClient.music
        .searchSongs(query, limit: 15)
        .timeout(const Duration(seconds: 12));
    return songs.map(musicSearchSong).toList();
  } catch (error, stackTrace) {
    logger.log(
      'YouTube Music song search unavailable',
      error: error,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Map<String, dynamic> musicSearchSong(MusicSong song) => {
  'ytid': song.id,
  'title': song.title,
  'artist': song.artists.join(', '),
  'artists': List<String>.from(song.artists),
  'videoAuthor': song.artists.isEmpty ? '' : '${song.artists.first} - Topic',
  'album': song.album ?? '',
  'duration': song.duration?.inSeconds,
  'image': song.thumbnailUrl,
  'lowResImage': song.thumbnailUrl,
  'highResImage': song.thumbnailUrl,
  'isExplicit': song.explicit,
  'sourceType': 'youtube_music_song',
};
