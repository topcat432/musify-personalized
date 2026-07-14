import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/spotify_import_destination_service.dart';

void main() {
  const service = SpotifyImportDestinationService();
  final snapshot = SpotifyImportDestinationSnapshot(
    sourceName: 'My Spotify songs',
    resolvedSongs: [
      {'ytid': 'song-1', 'title': 'One'},
      {'ytid': 'song-2', 'title': 'Two'},
      {'ytid': 'song-3', 'title': 'Three'},
    ],
    resolvedResultCount: 4,
    unresolvedCount: 24,
    customPlaylists: const [],
  );

  group('SpotifyImportDestinationService selection', () {
    test('selects an exact amount in source order', () {
      final selected = service.selectSongs(snapshot, 2);

      expect(selected.map((song) => song['ytid']), ['song-1', 'song-2']);
      expect(snapshot.duplicateMatchCount, 1);
    });

    test('clamps selection without losing unresolved count', () {
      final preview = service.preview(
        snapshot: snapshot,
        requestedCount: 99,
        destinationKind: SpotifyImportDestinationKind.newPlaylist,
      );

      expect(preview.selectedCount, 3);
      expect(preview.newCount, 3);
      expect(preview.alreadyPresentCount, 0);
      expect(preview.unresolvedCount, 24);
    });

    test('allows an empty preview but routing can reject it', () {
      expect(service.selectSongs(snapshot, -10), isEmpty);
    });
  });
}
