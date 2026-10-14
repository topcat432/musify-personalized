import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_source_playlist.dart';
import 'package:musify/services/spotify_source_playlist_projection.dart';

void main() {
  SpotifyPlaylistMember member(int position, int? row) => SpotifyPlaylistMember(
    position: position,
    sourceRow: row,
    issue: row == null ? 'Unavailable' : null,
    sourceMetadata: row == null
        ? const {}
        : {'uri': 'spotify:track:${(row == 1 ? 'A' : 'B') * 22}'},
  );
  SpotifySourcePlaylist source(int position, {String? uri}) =>
      SpotifySourcePlaylist(
        position: position,
        name: 'Same name',
        spotifyUri: uri,
        members: [member(1, 4), member(2, 1), member(3, 4), member(4, null)],
      );
  final tracks = [
    {'sourceRow': 1, 'spotifyTrackUri': 'spotify:track:${'A' * 22}'},
    {'sourceRow': 4, 'spotifyTrackUri': 'spotify:track:${'B' * 22}'},
  ];
  SpotifyImportDestinationSnapshot snapshot({
    bool reliable = true,
    bool partial = false,
  }) => SpotifyImportDestinationSnapshot(
    importSessionId: 'owned',
    sourceName: 'account.zip',
    resolvedSongs: [
      {'ytid': 'chosen-A', 'title': 'Selected A'},
      if (!partial) {'ytid': 'chosen-B', 'title': 'Selected B'},
    ],
    resolvedResultCount: partial ? 1 : 2,
    unresolvedCount: partial ? 1 : 0,
    customPlaylists: const [],
    sourceRowsReliable: reliable,
    resolvedRecordings: [
      {'sourceRow': '1', 'recordingId': 'chosen-A'},
      if (!partial) {'sourceRow': '4', 'recordingId': 'chosen-B'},
    ],
  );
  test(
    'source order differs from global order and preserves chosen recording identities',
    () {
      final p = SpotifySourcePlaylistProjection.project(
        sources: [source(1)],
        position: 1,
        tracks: tracks,
        snapshot: snapshot(),
      );
      expect(p.recordingIds, ['chosen-B', 'chosen-A']);
      expect(p.songs.map((s) => s['ytid']), p.recordingIds);
      expect(p.unsupportedMembers, 1);
      expect(p.pendingMembers, 0);
      expect(p.repeatedResolvedMembers, 1);
      expect(() => p.recordingIds.clear(), throwsUnsupportedError);
    },
  );
  test('same-name source positions have separate repeat-safe scope keys', () {
    final sources = [source(1), source(2)];
    final one = SpotifySourcePlaylistProjection.project(
      sources: sources,
      position: 1,
      tracks: tracks,
      snapshot: snapshot(),
    );
    final two = SpotifySourcePlaylistProjection.project(
      sources: sources,
      position: 2,
      tracks: tracks,
      snapshot: snapshot(),
    );
    expect(one.scopeKey, isNot(two.scopeKey));
    expect(one.fingerprint, isNot(two.fingerprint));
    expect(
      SpotifySourcePlaylistProjection.project(
        sources: sources,
        position: 1,
        tracks: tracks,
        snapshot: snapshot(),
      ).fingerprint,
      one.fingerprint,
    );
  });
  test('unresolved and unavailable positions stay separate from selection', () {
    final p = SpotifySourcePlaylistProjection.project(
      sources: [source(1)],
      position: 1,
      tracks: tracks,
      snapshot: snapshot(partial: true),
    );
    expect(p.recordingIds, ['chosen-A']);
    expect(p.pendingMembers, 2);
    expect(p.unsupportedMembers, 1);
  });
  test(
    'stable Spotify playlist URI is retained instead of a name-derived key',
    () {
      final uri = 'spotify:playlist:${'P' * 22}';
      expect(
        SpotifySourcePlaylistProjection.project(
          sources: [source(1, uri: uri)],
          position: 1,
          tracks: tracks,
          snapshot: snapshot(),
        ).scopeKey,
        uri,
      );
    },
  );
  test(
    'ambiguous source rows missing tracks and bad selections reject without writes',
    () {
      expect(
        () => SpotifySourcePlaylistProjection.project(
          sources: [source(1)],
          position: 1,
          tracks: tracks,
          snapshot: snapshot(reliable: false),
        ),
        throwsStateError,
      );
      expect(
        () => SpotifySourcePlaylistProjection.project(
          sources: [source(1)],
          position: 2,
          tracks: tracks,
          snapshot: snapshot(),
        ),
        throwsStateError,
      );
      expect(
        () => SpotifySourcePlaylistProjection.project(
          sources: [source(1)],
          position: 1,
          tracks: [tracks.first],
          snapshot: snapshot(),
        ),
        throwsStateError,
      );
      expect(
        () => SpotifySourcePlaylistProjection.project(
          sources: [source(1)],
          position: 1,
          tracks: [...tracks, tracks.first],
          snapshot: snapshot(),
        ),
        throwsStateError,
      );
    },
  );
}
