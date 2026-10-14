import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_playlist.dart';

/// Read-only source-order projection. Destination mutation stays in the
/// audited writer; unresolved/repeated source memberships are never removed.
class SpotifySourcePlaylistProjection {
  SpotifySourcePlaylistProjection._({
    required this.source,
    required this.scopeKey,
    required this.fingerprint,
    required this.recordingIds,
    required this.songs,
    required this.unsupportedMembers,
    required this.pendingMembers,
    required this.repeatedResolvedMembers,
  });
  final SpotifySourcePlaylist source;
  final String scopeKey, fingerprint;
  final List<String> recordingIds;
  final List<Map<String, dynamic>> songs;
  final int unsupportedMembers, pendingMembers, repeatedResolvedMembers;
  static SpotifySourcePlaylistProjection project({
    required List<SpotifySourcePlaylist> sources,
    required int position,
    required List<Map<String, dynamic>> tracks,
    required SpotifyImportDestinationSnapshot snapshot,
  }) {
    void require(bool condition) {
      if (!condition)
        throw StateError(
          'This source playlist cannot be selected safely. Reload the import; its source data was retained.',
        );
    }

    require(snapshot.importSessionId.isNotEmpty && snapshot.sourceRowsReliable);
    final payload = SpotifySourcePlaylistCodec.encode(sources);
    require(position >= 1 && position <= sources.length);
    final source = sources[position - 1];
    final tracksByRow = <int, Map<String, dynamic>>{};
    for (final track in tracks) {
      final row = track['sourceRow'];
      require(row is int && row > 0 && !tracksByRow.containsKey(row));
      tracksByRow[row as int] = track;
    }
    final resolved = <int, String>{};
    for (final row in snapshot.resolvedRecordings) {
      final index = int.tryParse(row['sourceRow'] ?? '');
      final id = row['recordingId'];
      require(
        index != null &&
            id != null &&
            id.isNotEmpty &&
            !resolved.containsKey(index),
      );
      resolved[index!] = id!;
    }
    final songsById = <String, Map<String, dynamic>>{};
    for (final song in snapshot.resolvedSongs) {
      final id = song['ytid'];
      require(id is String && id.isNotEmpty && !songsById.containsKey(id));
      songsById[id as String] = song;
    }
    final ids = <String>[];
    final seen = <String>{};
    var unsupported = 0, pending = 0, repeated = 0;
    for (final member in source.members) {
      final row = member.sourceRow;
      if (row == null) {
        unsupported++;
        continue;
      }
      final track = tracksByRow[row];
      require(
        track != null &&
            track['spotifyTrackUri'] == member.sourceMetadata['uri'],
      );
      final id = resolved[row];
      if (id == null) {
        pending++;
        continue;
      }
      require(songsById.containsKey(id));
      if (!seen.add(id)) {
        repeated++;
        continue;
      }
      ids.add(id);
    }
    return SpotifySourcePlaylistProjection._(
      source: source,
      scopeKey:
          source.spotifyUri ??
          'import:${snapshot.importSessionId}:playlist:$position',
      fingerprint: sha256
          .convert(
            utf8.encode(
              jsonEncode((payload['playlists'] as List)[position - 1]),
            ),
          )
          .toString(),
      recordingIds: List.unmodifiable(ids),
      songs: List.unmodifiable(
        ids.map((id) => Map<String, dynamic>.unmodifiable(songsById[id]!)),
      ),
      unsupportedMembers: unsupported,
      pendingMembers: pending,
      repeatedResolvedMembers: repeated,
    );
  }
}
