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

typedef SpotifyImportSessionWriter = Future<void> Function(
  Box<dynamic> box,
  Map<String, dynamic> values,
);

class SpotifyImportSessionService {
  const SpotifyImportSessionService({this.sessionWriter});

  final SpotifyImportSessionWriter? sessionWriter;

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
    final previousValues = <String, dynamic>{
      for (final key in _sessionKeys)
        if (box.containsKey(key)) key: box.get(key),
    };
    final newValues = <String, dynamic>{
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
        'importSessionId': savedAt.microsecondsSinceEpoch.toString(),
        'matchingStatus': 'not_started',
        'nextTrackIndex': 0,
      },
      'spotifyMatchResults': <dynamic>[],
      'spotifyExcludedImportRows': <dynamic>[],
    };

    try {
      await (sessionWriter ?? _writeSession)(box, newValues);
    } catch (error, stackTrace) {
      // A failed replacement must not destroy the user's last reviewable
      // import. Clear any partial writes, then restore the exact old key set.
      await box.deleteAll(_sessionKeys);
      await box.putAll(previousValues);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> _writeSession(
    Box<dynamic> box,
    Map<String, dynamic> values,
  ) => box.putAll(values);
}
