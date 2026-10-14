import 'dart:typed_data';
import 'package:musify/services/spotify_csv_importer.dart';

class SpotifyPlaylistMember {
  const SpotifyPlaylistMember({
    required this.position,
    required this.sourceRow,
    required this.issue,
    this.sourceMetadata = const {},
  });
  final int position;
  final int? sourceRow;
  final String? issue;
  final Map<String, String> sourceMetadata;
}

class SpotifySourcePlaylist {
  const SpotifySourcePlaylist({
    required this.position,
    required this.name,
    required this.spotifyUri,
    required this.members,
  });
  final int position;
  final String name;
  final String? spotifyUri;
  final List<SpotifyPlaylistMember> members;
}

/// Transient membership model only: no save or routing adapter may flatten it.
/// Compatibility: caseychu/spotify-backup named playlists with Web API tracks.
class SpotifyPlaylistDraft {
  SpotifyPlaylistDraft._(this.tracks, this.playlists, this.ignoredAlbums);
  final List<SpotifyImportTrack> tracks;
  final List<SpotifySourcePlaylist> playlists;
  final int ignoredAlbums;
  static const maxPlaylists = 200;
  static const maxMemberships = 10000;

  static SpotifyPlaylistDraft parseBytes(Uint8List bytes) {
    Never fail() => throw const SpotifyImportException(
      'Unsupported playlist JSON. Choose a compatible named-playlist backup; nothing was saved.',
    );
    final document = SpotifyCsvImporter.decodeBoundedJson(bytes);
    if (document is! Map<String, dynamic> ||
        document['playlists'] is! List ||
        document.keys.any((k) => k != 'playlists' && k != 'albums') ||
        (document.containsKey('albums') && document['albums'] is! List)) {
      fail();
    }
    final sources = document['playlists'] as List;
    if (sources.isEmpty || sources.length > maxPlaylists) {
      fail();
    }
    var total = 0;
    for (final source in sources) {
      if (source is! Map<String, dynamic> ||
          source['name'] is! String ||
          (source['name'] as String).trim().isEmpty ||
          source['tracks'] is! List) {
        fail();
      }
      total += (source['tracks'] as List).length;
      if (total > maxMemberships) {
        throw const SpotifyImportException(
          'Playlist backups must contain at most 10,000 memberships.',
        );
      }
    }
    final tracks = <SpotifyImportTrack>[];
    final playlists = <SpotifySourcePlaylist>[];
    final identities = <String, SpotifyImportTrack>{};
    var row = 0;
    for (final (index, source) in sources.indexed) {
      final members = <SpotifyPlaylistMember>[];
      final uri = source['uri'];
      if (uri != null &&
          (uri is! String ||
              !RegExp(r'^spotify:playlist:[A-Za-z0-9]{22}$').hasMatch(uri))) {
        fail();
      }
      for (final (position, item) in (source['tracks'] as List).indexed) {
        row++;
        final metadata = <String, String>{};
        if (item is Map<String, dynamic>) {
          if (item['added_at'] is String)
            metadata['addedAt'] = item['added_at'] as String;
          final rawTrack = item['track'];
          if (rawTrack is Map<String, dynamic>) {
            if (rawTrack['name'] is String)
              metadata['title'] = rawTrack['name'] as String;
            if (rawTrack['uri'] is String)
              metadata['uri'] = rawTrack['uri'] as String;
            final rawAlbum = rawTrack['album'];
            if (rawAlbum is Map<String, dynamic> && rawAlbum['name'] is String)
              metadata['album'] = rawAlbum['name'] as String;
            final rawArtists = rawTrack['artists'];
            if (rawArtists is List)
              metadata['artist'] = rawArtists
                  .whereType<Map<String, dynamic>>()
                  .where((a) => a['name'] is String)
                  .map((a) => a['name'] as String)
                  .join(', ');
          }
        }
        final sourceMetadata = Map<String, String>.unmodifiable(metadata);
        SpotifyPlaylistMember unsupported(String issue) =>
            SpotifyPlaylistMember(
              position: position + 1,
              sourceRow: null,
              issue: issue,
              sourceMetadata: sourceMetadata,
            );
        if (item is! Map<String, dynamic> ||
            item['track'] is! Map<String, dynamic>) {
          members.add(unsupported('Missing or unavailable track'));
          continue;
        }
        final track = item['track'] as Map<String, dynamic>;
        if (track['is_local'] == true) {
          members.add(unsupported('Local track; audio was not imported'));
          continue;
        }
        if (track['type'] != null && track['type'] != 'track') {
          members.add(unsupported('Non-song item; not imported'));
          continue;
        }
        final identity = track['uri'],
            title = track['name'],
            artists = track['artists'],
            album = track['album'];
        if (identity is! String ||
            !RegExp(r'^spotify:track:[A-Za-z0-9]{22}$').hasMatch(identity) ||
            title is! String ||
            title.trim().isEmpty ||
            artists is! List ||
            artists.isEmpty ||
            artists.any(
              (a) =>
                  a is! Map<String, dynamic> ||
                  a['name'] is! String ||
                  (a['name'] as String).trim().isEmpty,
            ) ||
            (album != null &&
                (album is! Map<String, dynamic> || album['name'] is! String))) {
          members.add(unsupported('Incomplete song identity or metadata'));
          continue;
        }
        final artist = artists
            .map((a) => (a['name'] as String).trim())
            .join(', ');
        final albumName = album == null ? '' : (album['name'] as String).trim();
        final duration = track['duration_ms'];
        if (duration != null &&
            (duration is! int || duration < 0 || duration > 86400000)) {
          members.add(unsupported('Invalid song duration'));
          continue;
        }
        final previous = identities[identity];
        if (previous != null &&
            (previous.title != title.trim() ||
                previous.artist != artist ||
                previous.album != albumName ||
                previous.durationMs != duration)) {
          throw const SpotifyImportException(
            'The same Spotify recording has conflicting metadata. Nothing was saved.',
          );
        }
        final selected =
            previous ??
            SpotifyImportTrack(
              sourceRow: row,
              title: title.trim(),
              artist: artist,
              album: albumName,
              isrc: '',
              durationMs: duration as int?,
              addedAt: null,
              spotifyTrackUri: identity,
              spotifyTrackId: identity.substring('spotify:track:'.length),
            );
        if (previous == null) {
          identities[identity] = selected;
          tracks.add(selected);
        }
        members.add(
          SpotifyPlaylistMember(
            position: position + 1,
            sourceRow: selected.sourceRow,
            issue: null,
            sourceMetadata: sourceMetadata,
          ),
        );
      }
      playlists.add(
        SpotifySourcePlaylist(
          position: index + 1,
          name: (source['name'] as String).trim(),
          spotifyUri: uri as String?,
          members: List.unmodifiable(members),
        ),
      );
    }
    return SpotifyPlaylistDraft._(
      List.unmodifiable(tracks),
      List.unmodifiable(playlists),
      (document['albums'] as List?)?.length ?? 0,
    );
  }
}
