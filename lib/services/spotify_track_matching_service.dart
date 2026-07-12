/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';

import 'package:hive/hive.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/spotify_match_scoring.dart';

class SpotifyMatchingSnapshot {
  const SpotifyMatchingSnapshot({
    required this.totalTracks,
    required this.nextTrackIndex,
    required this.matchedCount,
    required this.reviewCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.status,
    required this.recentResults,
  });

  final int totalTracks;
  final int nextTrackIndex;
  final int matchedCount;
  final int reviewCount;
  final int unmatchedCount;
  final int errorCount;
  final String status;
  final List<Map<String, dynamic>> recentResults;

  bool get hasImport => totalTracks > 0;
  bool get isComplete => totalTracks > 0 && nextTrackIndex >= totalTracks;
  double get progress => totalTracks == 0 ? 0 : nextTrackIndex / totalTracks;
}

class SpotifyTrackMatchingService {
  const SpotifyTrackMatchingService();

  static const int defaultBatchSize = 25;
  static const double automaticMatchThreshold = 0.90;
  static const double reviewThreshold = 0.70;

  Future<SpotifyMatchingSnapshot> loadSnapshot() async {
    final box = Hive.box('user');
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    return _snapshot(tracks, results, metadata);
  }

  Future<SpotifyMatchingSnapshot> matchNextBatch({
    int batchSize = defaultBatchSize,
    bool Function()? shouldStop,
    void Function(SpotifyMatchingSnapshot snapshot)? onProgress,
  }) async {
    final box = Hive.box('user');
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));

    if (tracks.isEmpty) return _snapshot(tracks, results, metadata);

    var nextIndex = _asInt(metadata['nextTrackIndex']) ?? results.length;
    nextIndex = nextIndex.clamp(0, tracks.length).toInt();
    if (results.length > nextIndex) {
      results.removeRange(nextIndex, results.length);
    }

    final stopIndex = (nextIndex + batchSize)
        .clamp(0, tracks.length)
        .toInt();
    metadata['matchingStatus'] = 'running';
    await _checkpoint(results, metadata, nextIndex, tracks.length);

    var sinceCheckpoint = 0;
    while (nextIndex < stopIndex) {
      if (shouldStop?.call() ?? false) break;

      final source = tracks[nextIndex];
      Map<String, dynamic> result;
      try {
        result = await _matchOne(source);
      } catch (error) {
        result = {
          'sourceRow': source['sourceRow'],
          'sourceTitle': source['title']?.toString() ?? '',
          'sourceArtist': source['artist']?.toString() ?? '',
          'status': 'error',
          'score': 0.0,
          'error': error.toString(),
          'matchedAt': DateTime.now().toUtc().toIso8601String(),
        };
      }

      results.add(result);
      nextIndex++;
      sinceCheckpoint++;

      if (sinceCheckpoint >= 5 || nextIndex >= stopIndex) {
        metadata['matchingStatus'] = nextIndex >= tracks.length
            ? 'complete'
            : 'paused';
        await _checkpoint(results, metadata, nextIndex, tracks.length);
        sinceCheckpoint = 0;
      }

      onProgress?.call(_snapshot(tracks, results, metadata));
      if (nextIndex < stopIndex) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    metadata['matchingStatus'] = nextIndex >= tracks.length
        ? 'complete'
        : 'paused';
    await _checkpoint(results, metadata, nextIndex, tracks.length);
    return _snapshot(tracks, results, metadata);
  }

  Future<Map<String, dynamic>> _matchOne(Map<String, dynamic> source) async {
    final title = source['title']?.toString().trim() ?? '';
    final artist = source['artist']?.toString().trim() ?? '';
    final durationMs = _asInt(source['durationMs']);
    final input = SpotifyMatchInput(
      title: title,
      artist: artist,
      durationMs: durationMs,
    );

    final primaryQuery = '$artist $title official audio'.trim();
    final primary = await fetchSongsList(primaryQuery);
    var ranked = _rank(input, primary);

    if (ranked.isEmpty ||
        (ranked.first['score'] as double) < reviewThreshold) {
      final fallback = await fetchSongsList('$artist $title'.trim());
      ranked = _rank(input, [...primary, ...fallback]);
    }

    final best = ranked.isEmpty ? null : ranked.first;
    final bestScore = best?['score'] as double? ?? 0.0;
    final status = best == null
        ? 'unmatched'
        : bestScore >= automaticMatchThreshold
        ? 'matched'
        : bestScore >= reviewThreshold
        ? 'needs_review'
        : 'unmatched';

    return {
      'sourceRow': source['sourceRow'],
      'sourceTitle': title,
      'sourceArtist': artist,
      'sourceAlbum': source['album']?.toString() ?? '',
      'sourceIsrc': source['isrc']?.toString() ?? '',
      'sourceDurationMs': durationMs,
      'status': status,
      'score': bestScore,
      'bestCandidate': best?['candidate'],
      'matchEvidence': best?['evidence'],
      'alternatives': ranked
          .take(3)
          .map(
            (item) => {
              'score': item['score'],
              'candidate': item['candidate'],
              'evidence': item['evidence'],
            },
          )
          .toList(growable: false),
      'matchedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  List<Map<String, dynamic>> _rank(
    SpotifyMatchInput input,
    Iterable<dynamic> candidates,
  ) {
    final seenIds = <String>{};
    final ranked = <Map<String, dynamic>>[];

    for (final raw in candidates) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      final id = candidate['ytid']?.toString() ?? '';
      if (id.isEmpty || !seenIds.add(id)) continue;

      final evidence = SpotifyMatchScorer.score(input, candidate);
      if (evidence.disqualified) continue;
      ranked.add({
        'score': evidence.score,
        'candidate': candidate,
        'evidence': evidence.toJson(),
      });
    }

    ranked.sort(
      (left, right) => (right['score'] as double).compareTo(
        left['score'] as double,
      ),
    );
    return ranked;
  }

  Future<void> _checkpoint(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> metadata,
    int nextIndex,
    int totalTracks,
  ) async {
    metadata['matchingVersion'] = 1;
    metadata['nextTrackIndex'] = nextIndex;
    metadata['matchedCount'] = _count(results, 'matched');
    metadata['reviewCount'] = _count(results, 'needs_review');
    metadata['unmatchedCount'] = _count(results, 'unmatched');
    metadata['errorCount'] = _count(results, 'error');
    metadata['validTrackCount'] = totalTracks;
    metadata['lastMatchingCheckpointAt'] = DateTime.now()
        .toUtc()
        .toIso8601String();

    await addOrUpdateData<List>('user', 'spotifyMatchResults', results);
    await addOrUpdateData<Map<String, dynamic>>(
      'user',
      'spotifyImportMetadata',
      metadata,
    );
  }

  SpotifyMatchingSnapshot _snapshot(
    List<Map<String, dynamic>> tracks,
    List<Map<String, dynamic>> results,
    Map<String, dynamic> metadata,
  ) {
    final nextIndex = (_asInt(metadata['nextTrackIndex']) ?? results.length)
        .clamp(0, tracks.length)
        .toInt();
    return SpotifyMatchingSnapshot(
      totalTracks: tracks.length,
      nextTrackIndex: nextIndex,
      matchedCount: _count(results, 'matched'),
      reviewCount: _count(results, 'needs_review'),
      unmatchedCount: _count(results, 'unmatched'),
      errorCount: _count(results, 'error'),
      status: metadata['matchingStatus']?.toString() ?? 'not_started',
      recentResults: results.reversed.take(10).toList(growable: false),
    );
  }

  static int _count(List<Map<String, dynamic>> results, String status) {
    return results.where((result) => result['status'] == status).length;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _readMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
  }
}
