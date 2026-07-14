/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:hive/hive.dart';
import 'package:musify/services/spotify_csv_importer.dart';

class SpotifyImportSessionService {
  const SpotifyImportSessionService();

  static const _sessionKeys = <String>[
    'spotifyImportTracks',
    'spotifyImportMetadata',
    'spotifyMatchResults',
    'spotifyExcludedImportRows',
  ];

  Future<void> saveNewImport(
    SpotifyImportPreview preview, {
    DateTime? importedAt,
  }) async {
    final box = Hive.box('user');
    final savedAt = (importedAt ?? DateTime.now()).toUtc();

    // Fail closed before installing the new source. Review and destination
    // screens must never observe a new CSV beside results from an older one.
    await box.deleteAll(_sessionKeys);
    await box.putAll({
      'spotifyImportTracks': preview.tracks
          .map((track) => track.toJson())
          .toList(growable: false),
      'spotifyImportMetadata': <String, dynamic>{
        'version': 1,
        'fileName': preview.fileName,
        'format': preview.format,
        'validTrackCount': preview.tracks.length,
        'rejectedRowCount': preview.rejectedRows.length,
        'totalDataRows': preview.totalDataRows,
        'importedAt': savedAt.toIso8601String(),
        'matchingStatus': 'not_started',
        'nextTrackIndex': 0,
      },
    });
  }
}
