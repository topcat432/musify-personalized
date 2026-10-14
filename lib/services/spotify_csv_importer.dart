/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:convert';
import 'dart:typed_data';

class SpotifyImportTrack {
  const SpotifyImportTrack({
    required this.sourceRow,
    required this.title,
    required this.artist,
    required this.album,
    required this.isrc,
    required this.durationMs,
    required this.addedAt,
    this.spotifyTrackUri,
    this.spotifyTrackId,
  });

  final int sourceRow;
  final String title;
  final String artist;
  final String album;
  final String isrc;
  final int? durationMs;
  final DateTime? addedAt;
  final String? spotifyTrackUri;
  final String? spotifyTrackId;

  Map<String, dynamic> toJson() => {
    'sourceRow': sourceRow,
    'title': title,
    'artist': artist,
    'album': album,
    'isrc': isrc,
    'durationMs': durationMs,
    'addedAt': addedAt?.toIso8601String(),
    ..._spotifyTrackIdentity(spotifyTrackUri ?? '', spotifyTrackId ?? ''),
  };
}

class SpotifyRejectedRow {
  const SpotifyRejectedRow({required this.sourceRow, required this.reason});

  final int sourceRow;
  final String reason;
}

class SpotifyImportPreview {
  const SpotifyImportPreview({
    required this.fileName,
    required this.format,
    required this.totalDataRows,
    required this.tracks,
    required this.rejectedRows,
    this.notices = const [],
  });

  final String fileName;
  final String format;
  final int totalDataRows;
  final List<SpotifyImportTrack> tracks;
  final List<SpotifyRejectedRow> rejectedRows;
  final List<String> notices;
}

class SpotifyImportException implements Exception {
  const SpotifyImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpotifyCsvImporter {
  const SpotifyCsvImporter._();

  static const maxJsonBytes = 8 * 1024 * 1024;
  static const maxJsonTracks = 10000;
  static const maxJsonDepth = 24;

  static SpotifyImportPreview parseBytes(
    Uint8List bytes, {
    required String fileName,
    bool rejectPlaylistMembership = false,
    int? maxDataRows,
  }) {
    if (fileName.toLowerCase().endsWith('.json')) {
      return _parseLibraryJson(bytes, fileName);
    }
    final isTsv = fileName.toLowerCase().endsWith('.tsv');
    if (bytes.isEmpty) {
      throw const SpotifyImportException(
        'The selected song-list file is empty.',
      );
    }

    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\ufeff', '');
    final rows = _parseDelimited(
      text,
      delimiter: isTsv ? '\t' : ',',
      maxDataRows: maxDataRows,
    );
    if (rows.length < 2) {
      throw const SpotifyImportException(
        'The song list must contain a header row and at least one song.',
      );
    }

    final headers = rows.first.map(_normalizeHeader).toList(growable: false);
    if ((rejectPlaylistMembership &&
            headers.any((header) => header.startsWith('playlist'))) ||
        ((isTsv || rejectPlaylistMembership) &&
            headers.any(
              (header) => const {
                'playlist',
                'playlist name',
                'playlist names',
                'playlist id',
                'playlist uri',
                'playlist membership',
                'playlists',
                'playlist_name',
                'playlist_id',
                'playlist_uri',
              }.contains(header),
            ))) {
      throw const SpotifyImportException(
        'This song list includes playlist membership. Use a flat song list; playlist-aware imports are not supported yet.',
      );
    }
    final titleIndex = _findHeader(headers, const [
      'track name',
      'title',
      'name',
    ]);
    final artistIndex = _findHeader(headers, const [
      'artist name(s)',
      'artist names',
      'artist',
      'artists',
    ]);

    if (titleIndex == null || artistIndex == null) {
      throw const SpotifyImportException(
        'Unsupported song list. A title/track-name column and an artist column are required.',
      );
    }

    final albumIndex = _findHeader(headers, const ['album name', 'album']);
    final isrcIndex = _findHeader(headers, const ['isrc']);
    final durationIndex = _findHeader(headers, const [
      'track duration (ms)',
      'duration (ms)',
      'duration ms',
      'duration_ms',
      'duration',
    ]);
    final durationIsExplicitMilliseconds =
        durationIndex != null &&
        const {
          'track duration (ms)',
          'duration (ms)',
          'duration ms',
          'duration_ms',
        }.contains(headers[durationIndex]);
    final addedAtIndex = _findHeader(headers, const [
      'added at',
      'date added',
      'added_at',
    ]);
    final spotifyUriIndex = _findHeader(headers, const [
      'track uri',
      'spotify track uri',
      'spotify uri',
      'spotify track url',
      'spotify url',
    ]);
    // Generic track IDs may belong to another catalog and are not Spotify proof.
    final spotifyIdIndex = _findHeader(headers, const [
      'spotify track id',
      'spotify id',
    ]);

    final detectedFormat =
        headers.contains('track uri') || headers.contains('track name')
        ? 'Spotify/Exportify'
        : headers.contains('index') && headers.contains('isrc')
        ? 'Soundiiz'
        : 'Generic music CSV';

    final format = isTsv
        ? detectedFormat == 'Generic music CSV'
              ? 'Generic music TSV'
              : '$detectedFormat TSV'
        : detectedFormat;

    final tracks = <SpotifyImportTrack>[];
    final rejectedRows = <SpotifyRejectedRow>[];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((value) => value.trim().isEmpty)) continue;

      final sourceRow = rowIndex + 1;
      final title = _valueAt(row, titleIndex).trim();
      final artist = _valueAt(row, artistIndex).trim();

      if (title.isEmpty || artist.isEmpty) {
        rejectedRows.add(
          SpotifyRejectedRow(
            sourceRow: sourceRow,
            reason: title.isEmpty
                ? 'Missing track title.'
                : 'Missing artist name.',
          ),
        );
        continue;
      }

      final spotifyIdentity = _spotifyTrackIdentity(
        _valueAt(row, spotifyUriIndex),
        _valueAt(row, spotifyIdIndex),
      );
      tracks.add(
        SpotifyImportTrack(
          sourceRow: sourceRow,
          title: title,
          artist: artist,
          album: _valueAt(row, albumIndex).trim(),
          isrc: _valueAt(row, isrcIndex).trim(),
          durationMs: _parseDurationMs(
            _valueAt(row, durationIndex),
            valuesAreMilliseconds: durationIsExplicitMilliseconds,
          ),
          addedAt: _parseDate(_valueAt(row, addedAtIndex)),
          spotifyTrackUri: spotifyIdentity['spotifyTrackUri'],
          spotifyTrackId: spotifyIdentity['spotifyTrackId'],
        ),
      );
    }

    if (tracks.isEmpty) {
      throw const SpotifyImportException(
        'No valid songs were found in the selected song list.',
      );
    }

    return SpotifyImportPreview(
      fileName: fileName,
      format: format,
      totalDataRows: rows.length - 1,
      tracks: List.unmodifiable(tracks),
      rejectedRows: List.unmodifiable(rejectedRows),
    );
  }

  static void _validateJsonStructure(String text) {
    final objects = <Set<String>?>[];
    final expectingKey = <bool>[];
    var quoted = false;
    var escaped = false;
    var key = false;
    var start = 0;
    for (var index = 0; index < text.length; index++) {
      final code = text.codeUnitAt(index);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 92) {
          escaped = true;
        } else if (code == 34) {
          quoted = false;
          if (key &&
              !objects.last!.add(
                jsonDecode(text.substring(start, index + 1)) as String,
              )) {
            throw const SpotifyImportException(
              'The JSON contains duplicate fields.',
            );
          }
        }
      } else if (code == 34) {
        quoted = true;
        start = index;
        key = objects.isNotEmpty && objects.last != null && expectingKey.last;
      } else if (code == 123 || code == 91) {
        if (objects.length >= maxJsonDepth)
          throw const SpotifyImportException('The JSON is nested too deeply.');
        objects.add(code == 123 ? <String>{} : null);
        expectingKey.add(code == 123);
      } else if (code == 125 || code == 93) {
        if (objects.isEmpty)
          throw const FormatException('Unexpected closing bracket');
        objects.removeLast();
        expectingKey.removeLast();
      } else if (objects.isNotEmpty && objects.last != null) {
        if (code == 44) expectingKey[expectingKey.length - 1] = true;
        if (code == 58) expectingKey[expectingKey.length - 1] = false;
      }
    }
  }

  static SpotifyImportPreview _parseLibraryJson(
    Uint8List bytes,
    String fileName,
  ) {
    if (bytes.length > maxJsonBytes) {
      throw const SpotifyImportException(
        'JSON song lists must be 8 MiB or smaller.',
      );
    }
    dynamic document;
    try {
      final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
      _validateJsonStructure(text);
      document = jsonDecode(text);
    } on FormatException {
      throw const SpotifyImportException(
        'The selected JSON is malformed or is not valid UTF-8.',
      );
    }
    const sections = [
      'albums',
      'shows',
      'episodes',
      'bannedTracks',
      'artists',
      'bannedArtists',
      'other',
    ];
    if (document is! Map<String, dynamic> ||
        document['tracks'] is! List ||
        document.keys.any(
          (key) => key != 'tracks' && !sections.contains(key),
        )) {
      throw const SpotifyImportException(
        'Only Spotify YourLibrary saved-track JSON is supported. Playlist and other JSON formats are not imported.',
      );
    }
    final rows = document['tracks'] as List;
    if (rows.length > maxJsonTracks) {
      throw const SpotifyImportException(
        'JSON song lists may contain at most 10,000 tracks.',
      );
    }
    final notices = <String>[];
    for (final section in sections) {
      if (!document.containsKey(section)) continue;
      final values = document[section];
      if (values is! List) {
        throw const SpotifyImportException(
          'YourLibrary sections must be arrays.',
        );
      }
      if (values.isNotEmpty) {
        final label = const {
          'albums': 'Albums',
          'shows': 'Shows',
          'episodes': 'Episodes',
          'bannedTracks': 'Blocked songs',
          'artists': 'Artists',
          'bannedArtists': 'Blocked artists',
          'other': 'Other library items',
        }[section]!;
        notices.add(
          '$label: ${values.length} ${values.length == 1 ? 'entry' : 'entries'} not imported.',
        );
      }
    }
    if (notices.isNotEmpty) {
      notices.insert(
        0,
        'Saved songs only. Album/artist collections, podcasts and blocked-item preferences stay in the export.',
      );
    }
    final tracks = <SpotifyImportTrack>[];
    final rejected = <SpotifyRejectedRow>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      String? reason;
      if (row is! Map<String, dynamic> ||
          row.keys.any(
            (key) => !const ['artist', 'track', 'album', 'uri'].contains(key),
          )) {
        reason = 'Unsupported saved-track entry.';
      } else if (row['track'] is! String ||
          (row['track'] as String).trim().isEmpty) {
        reason = 'Missing track title.';
      } else if (row['artist'] is! String ||
          (row['artist'] as String).trim().isEmpty) {
        reason = 'Missing artist name.';
      } else if ((row['album'] != null && row['album'] is! String) ||
          (row['uri'] != null && row['uri'] is! String)) {
        reason = 'Album and URI must be text.';
      }
      final identity = reason == null
          ? _spotifyTrackIdentity((row['uri'] as String?) ?? '', '')
          : const <String, String>{};
      if (reason == null &&
          (row['uri'] as String?)?.trim().isNotEmpty == true &&
          identity.isEmpty) {
        reason = 'Not a supported Spotify track URI.';
      }
      if (reason != null) {
        rejected.add(SpotifyRejectedRow(sourceRow: index + 1, reason: reason));
        continue;
      }
      tracks.add(
        SpotifyImportTrack(
          sourceRow: index + 1,
          title: (row['track'] as String).trim(),
          artist: (row['artist'] as String).trim(),
          album: ((row['album'] as String?) ?? '').trim(),
          isrc: '',
          durationMs: null,
          addedAt: null,
          spotifyTrackUri: identity['spotifyTrackUri'],
          spotifyTrackId: identity['spotifyTrackId'],
        ),
      );
    }
    if (tracks.isEmpty) {
      throw const SpotifyImportException(
        'No valid saved tracks were found in this JSON.',
      );
    }
    return SpotifyImportPreview(
      fileName: fileName,
      format: 'Spotify saved tracks JSON',
      totalDataRows: rows.length,
      tracks: List.unmodifiable(tracks),
      rejectedRows: List.unmodifiable(rejected),
      notices: List.unmodifiable(notices),
    );
  }

  static List<List<String>> _parseDelimited(
    String input, {
    required String delimiter,
    int? maxDataRows,
  }) {
    if (maxDataRows != null && maxDataRows < 0) {
      throw ArgumentError.value(maxDataRows, 'maxDataRows');
    }
    final rows = <List<String>>[];
    var pendingBlankRows = 0;
    void retainRow(List<String> completedRow) {
      if (maxDataRows == null || rows.isEmpty) {
        rows.add(completedRow);
        return;
      }
      // Trailing blank records have always been ignored. Count them without
      // retaining their fields until a later nonblank record makes them data.
      if (completedRow.every((value) => value.trim().isEmpty)) {
        pendingBlankRows++;
        return;
      }
      if (rows.length - 1 + pendingBlankRows + 1 > maxDataRows) {
        throw SpotifyImportException(
          'ZIP song lists must contain at most $maxDataRows data rows.',
        );
      }
      for (var index = 0; index < pendingBlankRows; index++) {
        rows.add(const <String>[]);
      }
      pendingBlankRows = 0;
      rows.add(completedRow);
    }

    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];

      if (inQuotes) {
        if (character == '"') {
          final isEscapedQuote =
              index + 1 < input.length && input[index + 1] == '"';
          if (isEscapedQuote) {
            field.write('"');
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(character);
        }
        continue;
      }

      if (character == '"') {
        inQuotes = true;
      } else if (character == delimiter) {
        row.add(field.toString());
        field.clear();
      } else if (character == '\n' || character == '\r') {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field.clear();
        retainRow(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }

    if (inQuotes) {
      throw const SpotifyImportException(
        'The song list contains an unterminated quoted field.',
      );
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      retainRow(row);
    }

    while (rows.isNotEmpty &&
        rows.last.every((value) => value.trim().isEmpty)) {
      rows.removeLast();
    }

    return rows;
  }

  static String _normalizeHeader(String value) {
    return value
        .replaceFirst('\ufeff', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int? _findHeader(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(candidate);
      if (index >= 0) return index;
    }
    return null;
  }

  static String _valueAt(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index];
  }

  static int? _parseDurationMs(
    String value, {
    required bool valuesAreMilliseconds,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;

    // Only ambiguous generic duration columns need the seconds fallback.
    return !valuesAreMilliseconds && parsed < 10000 ? parsed * 1000 : parsed;
  }

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized)?.toUtc();
  }
}

// Metadata validation only: never resolves a link or grants playback access.
Map<String, String> _spotifyTrackIdentity(String rawUri, String rawId) {
  final location = rawUri.trim();
  final suppliedId = rawId.trim();
  final idPattern = RegExp(r'^[A-Za-z0-9]{22}$');
  String? uriId;
  if (location.isNotEmpty) {
    final direct = RegExp(
      r'^spotify:track:([A-Za-z0-9]{22})$',
    ).firstMatch(location);
    if (direct != null) {
      uriId = direct.group(1);
    } else {
      // Do not accept encoded path/host spelling that Uri would silently decode.
      if (location.split(RegExp('[?#]')).first.contains('%')) return const {};
      final uri = Uri.tryParse(location);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'open.spotify.com' ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && uri.port != 443))
        return const {};
      uriId = RegExp(
        r'^/(?:intl-[a-z]{2}/)?track/([A-Za-z0-9]{22})/?$',
      ).firstMatch(uri.path)?.group(1);
      if (uriId == null) return const {};
    }
  }
  if (suppliedId.isNotEmpty && !idPattern.hasMatch(suppliedId)) return const {};
  if (uriId != null && suppliedId.isNotEmpty && uriId != suppliedId)
    return const {};
  final id = uriId ?? (suppliedId.isNotEmpty ? suppliedId : null);
  if (id == null) return const {};
  return {'spotifyTrackUri': 'spotify:track:$id', 'spotifyTrackId': id};
}
