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
  });

  final int sourceRow;
  final String title;
  final String artist;
  final String album;
  final String isrc;
  final int? durationMs;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
    'sourceRow': sourceRow,
    'title': title,
    'artist': artist,
    'album': album,
    'isrc': isrc,
    'durationMs': durationMs,
    'addedAt': addedAt?.toIso8601String(),
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
  });

  final String fileName;
  final String format;
  final int totalDataRows;
  final List<SpotifyImportTrack> tracks;
  final List<SpotifyRejectedRow> rejectedRows;
}

class SpotifyImportException implements Exception {
  const SpotifyImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpotifyCsvImporter {
  const SpotifyCsvImporter._();

  static SpotifyImportPreview parseBytes(Uint8List bytes, {required String fileName}) {
    if (bytes.isEmpty) {
      throw const SpotifyImportException('The selected CSV file is empty.');
    }

    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
    final rows = _parseCsv(text);
    if (rows.length < 2) {
      throw const SpotifyImportException(
        'The CSV must contain a header row and at least one song.',
      );
    }

    final headers = rows.first.map(_normalizeHeader).toList(growable: false);
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
        'Unsupported CSV. A title/track-name column and an artist column are required.',
      );
    }

    final albumIndex = _findHeader(headers, const ['album name', 'album']);
    final isrcIndex = _findHeader(headers, const ['isrc']);
    final durationIndex = _findHeader(headers, const [
      'track duration (ms)',
      'duration ms',
      'duration_ms',
      'duration',
    ]);
    final addedAtIndex = _findHeader(headers, const [
      'added at',
      'date added',
      'added_at',
    ]);

    final format = headers.contains('track uri') || headers.contains('track name')
        ? 'Spotify/Exportify'
        : headers.contains('index') && headers.contains('isrc')
        ? 'Soundiiz'
        : 'Generic music CSV';

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

      tracks.add(
        SpotifyImportTrack(
          sourceRow: sourceRow,
          title: title,
          artist: artist,
          album: _valueAt(row, albumIndex).trim(),
          isrc: _valueAt(row, isrcIndex).trim(),
          durationMs: _parseDurationMs(_valueAt(row, durationIndex)),
          addedAt: _parseDate(_valueAt(row, addedAtIndex)),
        ),
      );
    }

    if (tracks.isEmpty) {
      throw const SpotifyImportException(
        'No valid songs were found in the selected CSV.',
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

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];

      if (inQuotes) {
        if (character == '"') {
          final isEscapedQuote = index + 1 < input.length && input[index + 1] == '"';
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
      } else if (character == ',') {
        row.add(field.toString());
        field.clear();
      } else if (character == '\n' || character == '\r') {
        if (character == '\r' && index + 1 < input.length && input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }

    if (inQuotes) {
      throw const SpotifyImportException(
        'The CSV contains an unterminated quoted field.',
      );
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }

    while (rows.isNotEmpty && rows.last.every((value) => value.trim().isEmpty)) {
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

  static int? _parseDurationMs(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;

    // Generic CSVs sometimes store whole seconds rather than milliseconds.
    return parsed < 10000 ? parsed * 1000 : parsed;
  }

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized)?.toUtc();
  }
}
