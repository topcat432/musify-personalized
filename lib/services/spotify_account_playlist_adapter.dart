import 'package:musify/services/spotify_csv_importer.dart';

/// Translates the evidenced Spotify account Playlist*.json shape to the existing
/// transient playlist parser. No source IDs, timestamps or durations are invented.
class SpotifyAccountPlaylistAdapter {
  const SpotifyAccountPlaylistAdapter._();

  static Map<String, dynamic>? normalize(Map<String, dynamic> document) {
    final sources = document['playlists'];
    if (sources is! List || !sources.any((source) => source is Map &&
        (source.containsKey('items') || source.containsKey('lastModifiedDate')))) {
      return null;
    }
    Never fail() => throw const SpotifyImportException(
      'Unsupported or mixed account playlist JSON. Nothing was saved.',
    );
    if (document.keys.any((key) => key != 'playlists') ||
        sources.isEmpty || sources.length > 200) fail();
    var total = 0;
    // Validate counts before allocating translated membership lists.
    for (final source in sources) {
      if (source is! Map<String, dynamic> || source['name'] is! String ||
          (source['name'] as String).trim().isEmpty ||
          source['lastModifiedDate'] is! String || source['items'] is! List ||
          source.keys.any((key) => !const {
            'name', 'lastModifiedDate', 'items', 'description',
            'numberOfFollowers', 'collaborators',
          }.contains(key))) fail();
      total += (source['items'] as List).length;
      if (total > 10000) throw const SpotifyImportException(
        'Playlist backups must contain at most 10,000 memberships.',
      );
    }
    final output = <Map<String, dynamic>>[];
    for (final source in sources) {
      final items = <Object?>[];
      for (final item in source['items'] as List) {
        if (item is! Map<String, dynamic>) {
          items.add(null);
          continue;
        }
        // Unknown item variants remain unsupported slots, rather than songs or
        // empty sources. Only these four track fields are evidenced here.
        final track = item['track'];
        final translated = track is Map<String, dynamic>
            ? <String, dynamic>{
                'uri': track['trackUri'], 'name': track['trackName'],
                'artists': [{'name': track['artistName']}],
                if (track.containsKey('albumName'))
                  'album': {'name': track['albumName']},
              }
            : null;
        if (track is Map<String, dynamic> && track.keys.any((key) => !const {
          'trackName', 'artistName', 'albumName', 'trackUri',
        }.contains(key))) fail();
        final hasOtherVariant = item.entries.any((entry) =>
            !const {'track', 'addedDate'}.contains(entry.key) && entry.value != null);
        if (hasOtherVariant) {
          items.add({
            'track': {...?translated, 'type': 'unsupported-account-item'},
            if (item['addedDate'] is String) 'added_at': item['addedDate'],
          });
        } else {
          items.add({
            'track': translated,
            if (item['addedDate'] is String) 'added_at': item['addedDate'],
          });
        }
      }
      output.add({'name': source['name'], 'tracks': items});
    }
    return {'playlists': output};
  }
}
