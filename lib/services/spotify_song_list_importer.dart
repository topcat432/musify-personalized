import 'dart:typed_data';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_playlist_draft.dart';

class SpotifySongListImporter {
  const SpotifySongListImporter._();
  static SpotifyImportPreview parseBytes(
    Uint8List bytes, {
    required String fileName,
    bool rejectPlaylistMembership = false,
    int? maxDataRows,
  }) {
    if (fileName.toLowerCase().endsWith('.json')) {
      final document = SpotifyCsvImporter.decodeBoundedJson(bytes);
      if (document is Map && document.containsKey('playlists')) {
        return SpotifyPlaylistDraft.parseBytes(
          bytes,
        ).toPreview(fileName: fileName);
      }
    }
    return SpotifyCsvImporter.parseBytes(
      bytes,
      fileName: fileName,
      rejectPlaylistMembership: rejectPlaylistMembership,
      maxDataRows: maxDataRows,
    );
  }
}
