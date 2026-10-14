import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/services/spotify_source_playlist.dart';

/// Completeness is derived from raw retained rows, never from legacy counts.
/// This is a transient guard on the existing all-recordings transaction.
class SpotifyWholeSourceReadiness {
  const SpotifyWholeSourceReadiness({
    required this.sourceRows,
    required this.pending,
    required this.excluded,
    required this.unsupported,
    required this.unknown,
    required this.repeatedMemberships,
    required this.fingerprint,
    this.rejectedInputRows = 0,
    this.emptyNamedSource = false,
    this.issue,
  });
  final int sourceRows,
      pending,
      excluded,
      unsupported,
      unknown,
      repeatedMemberships;
  final String? fingerprint;
  final int rejectedInputRows;
  final String? issue;
  final bool emptyNamedSource;
  bool get verifiedEmpty => emptyNamedSource && sourceRows == 0 &&
      pending == 0 && excluded == 0 && unsupported == 0 &&
      rejectedInputRows == 0 && unknown == 0 && fingerprint != null;
  bool get ready =>
      sourceRows > 0 &&
      pending == 0 &&
      excluded == 0 &&
      unsupported == 0 &&
      rejectedInputRows == 0 &&
      unknown == 0 &&
      fingerprint != null;
  static SpotifyWholeSourceReadiness inspect({
    required Object? rawTracks,
    required Object? rawResults,
    Object? rawExcludedRows,
    required Map<String, dynamic> metadata,
    int? sourcePlaylistPosition,
  }) {
    if ((rawTracks is List &&
            rawTracks.length > SpotifyCsvImporter.maxJsonTracks) ||
        (rawResults is List &&
            rawResults.length > SpotifyCsvImporter.maxJsonTracks)) {
      return SpotifyWholeSourceReadiness(
        sourceRows: rawTracks is List ? rawTracks.length : 0,
        pending: 0,
        excluded: 0,
        unsupported: 0,
        unknown: 1,
        repeatedMemberships: 0,
        fingerprint: null,
        issue:
            'Whole-source verification supports at most 10000 retained rows. Choose an explicit partial transfer for this import.',
      );
    }
    var unknown = hasStableImportSessionIdentity(metadata) ? 0 : 1;
    if (metadata.containsKey('version') &&
        (metadata['version'] is! int || metadata['version'] != 1))
      unknown++;
    if (metadata['importSessionId'] != null &&
        metadata['importSessionId'] is! String)
      unknown++;
    if (metadata['format'] == 'Named Spotify playlist backup' &&
        metadata[SpotifySourcePlaylistCodec.metadataKey] == null)
      unknown++;
    var pending = 0,
        excluded = 0,
        unsupported = 0,
        repeated = 0,
        rejectedInput = 0;
    final tracks = <int, Map>{};
    if (rawTracks is! List) {
      unknown++;
    } else {
      for (final raw in rawTracks) {
        if (raw is! Map) {
          unknown++;
          continue;
        }
        final row = raw['sourceRow'];
        if (row is! int ||
            row <= 0 ||
            tracks.containsKey(row) ||
            raw['title'] is! String ||
            (raw['title'] as String).trim().isEmpty ||
            raw['artist'] is! String ||
            (raw['artist'] as String).trim().isEmpty) {
          unknown++;
          continue;
        }
        tracks[row] = raw;
      }
    }
    if (metadata.containsKey('validTrackCount')) {
      final declared = metadata['validTrackCount'];
      if (declared is! int ||
          declared < 0 ||
          rawTracks is! List ||
          declared != rawTracks.length)
        unknown++;
    }
    if (metadata.containsKey('rejectedRowCount')) {
      final rejected = metadata['rejectedRowCount'];
      if (rejected is! int || rejected < 0)
        unknown++;
      else if (sourcePlaylistPosition == null)
        rejectedInput = rejected;
    }
    if (metadata.containsKey(SpotifySourcePlaylistCodec.metadataKey) &&
        metadata[SpotifySourcePlaylistCodec.metadataKey] == null)
      unknown++;
    var scope = tracks.keys.toSet();
    var emptyNamedSource = false;
    try {
      final sources = SpotifySourcePlaylistCodec.readSaved(
        metadata[SpotifySourcePlaylistCodec.metadataKey],
        rawTracks,
      );
      // Counts are integrity declarations, not evidence that missing rows were
      // completed. Older imports lacking a total remain explicitly partial.
      final total = metadata['totalDataRows'];
      final rejected = metadata['rejectedRowCount'];
      final hasMembership = metadata.containsKey(
        SpotifySourcePlaylistCodec.metadataKey,
      );
      final retained = hasMembership
          ? sources.fold<int>(
              0,
              (count, source) => count + source.members.length,
            )
          : rawTracks is List
          ? rawTracks.length
          : -1;
      final unsupportedTotal = sources.fold<int>(
        0,
        (count, source) =>
            count +
            source.members.where((member) => member.sourceRow == null).length,
      );
      if (total is! int ||
          total < 0 ||
          rejected is! int ||
          rejected < 0 ||
          retained < 0 ||
          total != retained + (hasMembership ? 0 : rejected) ||
          (hasMembership && rejected != unsupportedTotal))
        unknown++;
      final Iterable<SpotifySourcePlaylist> selected;
      if (sourcePlaylistPosition == null) {
        selected = sources;
      } else if (sourcePlaylistPosition <= 0 ||
          sourcePlaylistPosition > sources.length) {
        unknown++;
        selected = const [];
        scope = {};
      } else {
        selected = [sources[sourcePlaylistPosition - 1]];
        emptyNamedSource = sources[sourcePlaylistPosition - 1].members.isEmpty;
        scope = {};
      }
      final seen = <int>{};
      for (final source in selected) {
        for (final member in source.members) {
          if (member.sourceRow == null) {
            unsupported++;
            continue;
          }
          if (!seen.add(member.sourceRow!)) repeated++;
          if (sourcePlaylistPosition != null) scope.add(member.sourceRow!);
        }
      }
    } catch (_) {
      unknown++;
    }
    final results = <int, Map>{};
    if (rawResults is! List) {
      unknown++;
    } else {
      for (final raw in rawResults) {
        if (raw is! Map) {
          unknown++;
          continue;
        }
        final row = raw['sourceRow'];
        if (row is! int ||
            row <= 0 ||
            !tracks.containsKey(row) ||
            results.containsKey(row)) {
          unknown++;
          continue;
        }
        results[row] = raw;
      }
    }
    final explicitExclusions = <int>{};
    if (rawExcludedRows != null) {
      if (rawExcludedRows is! List ||
          rawExcludedRows.length > SpotifyCsvImporter.maxJsonTracks) {
        unknown++;
      } else {
        for (final raw in rawExcludedRows) {
          final row = int.tryParse(importRecordingRow(raw) ?? '');
          if (row == null || !tracks.containsKey(row))
            unknown++;
          else
            explicitExclusions.add(row);
        }
      }
    }
    for (final row in scope) {
      if (explicitExclusions.contains(row)) {
        excluded++;
        continue;
      }
      final result = results[row];
      if (result == null) {
        pending++;
        continue;
      }
      if (result['status'] == 'excluded') {
        excluded++;
        continue;
      }
      final status = result['status'];
      if (status == 'matched' || status == 'manually_matched') {
        final candidate = result['bestCandidate'];
        if (candidate is! Map ||
            candidate['ytid'] is! String ||
            (candidate['ytid'] as String).trim().isEmpty)
          unknown++;
      } else if ([
        'unmatched',
        'review',
        'error',
        'pending',
        'matching',
      ].contains(status)) {
        pending++;
      } else {
        unknown++;
      }
    }
    String? fingerprint;
    if (unknown == 0 &&
        pending == 0 &&
        excluded == 0 &&
        unsupported == 0 &&
        rejectedInput == 0 &&
        (scope.isNotEmpty || emptyNamedSource)) {
      try {
        fingerprint = sha256
            .convert(
              utf8.encode(
                jsonEncode(
                  _canonical({
                    'session': importSessionIdentity(metadata),
                    'version': metadata['version'],
                    'exclusions': rawExcludedRows,
                    'stable': hasStableImportSessionIdentity(metadata),
                    'fileName': metadata['fileName'],
                    'format': metadata['format'],
                    'validTrackCount': metadata['validTrackCount'],
                    'totalDataRows': metadata['totalDataRows'],
                    'rejectedRowCount': metadata['rejectedRowCount'],
                    'tracks': rawTracks,
                    'results': rawResults,
                    'sources': metadata[SpotifySourcePlaylistCodec.metadataKey],
                    'position': sourcePlaylistPosition,
                  }),
                ),
              ),
            )
            .toString();
      } catch (_) {
        unknown++;
      }
    }
    return SpotifyWholeSourceReadiness(
      emptyNamedSource: emptyNamedSource,
      sourceRows: scope.length,
      pending: pending,
      excluded: excluded,
      unsupported: unsupported,
      rejectedInputRows: rejectedInput,
      unknown: unknown,
      repeatedMemberships: repeated,
      fingerprint: fingerprint,
    );
  }

  static Object? _canonical(Object? value) {
    var nodes = 0, characters = 0;
    Object? walk(Object? item, int depth) {
      if (++nodes > 500000 || depth > 64) throw const FormatException();
      if (item is String) {
        characters += item.length;
        if (characters > 8 * 1024 * 1024) throw const FormatException();
      }
      if (item is Map) {
        if (item.length > 500000 || item.keys.any((key) => key is! String))
          throw const FormatException();
        final keys = item.keys.cast<String>().toList()..sort();
        for (final key in keys) {
          characters += key.length;
          if (characters > 8 * 1024 * 1024) throw const FormatException();
        }
        return {for (final key in keys) key: walk(item[key], depth + 1)};
      }
      if (item is List) {
        if (item.length > 500000) throw const FormatException();
        return item.map((entry) => walk(entry, depth + 1)).toList();
      }
      if (item == null ||
          item is bool ||
          item is String ||
          (item is num && item.isFinite))
        return item;
      throw const FormatException();
    }

    return walk(value, 0);
  }
}
