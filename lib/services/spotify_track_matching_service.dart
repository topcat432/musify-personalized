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
import 'package:musify/services/spotify_match_scoring.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

class SpotifyMatchingSnapshot {
  const SpotifyMatchingSnapshot({
    required this.totalTracks,
    required this.nextTrackIndex,
    required this.matchedCount,
    required this.reviewCount,
    required this.unmatchedCount,
    required this.errorCount,
    required this.excludedCount,
    required this.pendingResolutionCount,
    required this.status,
    required this.recentResults,
  });

  final int totalTracks;
  final int nextTrackIndex;
  final int matchedCount;
  final int reviewCount;
  final int unmatchedCount;
  final int errorCount;
  final int excludedCount;
  final int pendingResolutionCount;
  final String status;
  final List<Map<String, dynamic>> recentResults;

  bool get hasImport => totalTracks > 0;
  bool get isComplete => totalTracks > 0 && nextTrackIndex >= totalTracks;
  int get remainingCount => (totalTracks - nextTrackIndex).clamp(0, totalTracks);
  double get progress => totalTracks == 0 ? 0 : nextTrackIndex / totalTracks;
}

class SpotifyTrackMatchingService {
  const SpotifyTrackMatchingService();

  static const int defaultBatchSize = 25;
  static const int maximumPilotBatchSize = 50;
  static const int minimumUsablePilotAttempts = 40;
  static const double automaticMatchThreshold = 0.86;
  static const double reviewThreshold = 0.58;
  static const Duration _musicSearchTimeout = Duration(seconds: 18);
  static final YoutubeMusicExplode _youtubeMusic = YoutubeMusicExplode();

  static bool isFullLibraryRunUnlocked(SpotifyMatchingSnapshot snapshot) {
    if (snapshot.nextTrackIndex < maximumPilotBatchSize) return false;
    final usableAttempts =
        snapshot.nextTrackIndex - snapshot.errorCount - snapshot.excludedCount;
    if (usableAttempts < minimumUsablePilotAttempts) return false;
    final strongOrReview = snapshot.matchedCount + snapshot.reviewCount;
    final usefulRate = strongOrReview / usableAttempts;
    final unmatchedRate = snapshot.unmatchedCount / usableAttempts;
    return usefulRate >= 0.90 && unmatchedRate <= 0.10;
  }

  Future<SpotifyMatchingSnapshot> loadSnapshot() async {
    final box = Hive.box('user');
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    return _snapshot(tracks, results, metadata);
  }

  Future<List<Map<String, dynamic>>> loadReviewItems() async {
    final results = _readMaps(Hive.box('user').get('spotifyMatchResults'));
    final reviewItems = results
        .where((result) => result['status'] == 'needs_review')
        .toList(growable: false)
      ..sort((left, right) {
        final leftRow = _asInt(left['sourceRow']) ?? 0;
        final rightRow = _asInt(right['sourceRow']) ?? 0;
        return leftRow.compareTo(rightRow);
      });
    return reviewItems;
  }

  Future<SpotifyMatchingSnapshot> restartMatching() async {
    final box = Hive.box('user');
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final excludedRows = _readExcludedRows(box);
    metadata
      ..['matchingVersion'] = 3
      ..['matchingStatus'] = 'not_started'
      ..['nextTrackIndex'] = 0
      ..['matchedCount'] = 0
      ..['reviewCount'] = 0
      ..['unmatchedCount'] = 0
      ..['errorCount'] = 0
      ..['excludedCount'] = excludedRows.length
      ..['pendingResolutionCount'] = 0
      ..['lastMatchingCheckpointAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    await box.putAll({
      'spotifyMatchResults': <dynamic>[],
      'spotifyImportMetadata': metadata,
    });
    return _snapshot(tracks, <Map<String, dynamic>>[], metadata);
  }

  Future<SpotifyMatchingSnapshot> resolveReviewItem({
    required Object? sourceRow,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  }) async {
    final box = Hive.box('user');
    final tracks = _readMaps(box.get('spotifyImportTracks'));
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));

    final resultIndex = results.indexWhere(
      (result) =>
          result['sourceRow']?.toString() == sourceRow?.toString() &&
          result['status'] == 'needs_review',
    );
    if (resultIndex == -1) {
      return _snapshot(tracks, results, metadata);
    }

    final updated = Map<String, dynamic>.from(results[resultIndex]);
    if (accept) {
      final candidate = selectedAlternative?['candidate'];
      if (candidate is! Map) {
        throw StateError('The selected match is no longer available.');
      }
      updated
        ..['status'] = 'manually_matched'
        ..['score'] = _asDouble(selectedAlternative?['score']) ?? 0.0
        ..['bestCandidate'] = Map<String, dynamic>.from(candidate)
        ..['matchEvidence'] = selectedAlternative?['evidence']
        ..['reviewDecision'] = 'accepted';
    } else {
      updated
        ..['status'] = 'manual_unmatched'
        ..['score'] = 0.0
        ..['bestCandidate'] = null
        ..['matchEvidence'] = null
        ..['reviewDecision'] = 'no_correct_match';
    }
    updated['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
    results[resultIndex] = updated;

    final nextIndex = (_asInt(metadata['nextTrackIndex']) ?? results.length)
        .clamp(0, tracks.length);
    await _checkpoint(results, metadata, nextIndex, tracks.length);
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
    final excludedRows = _readExcludedRows(box);

    if (tracks.isEmpty) return _snapshot(tracks, results, metadata);

    var nextIndex = _asInt(metadata['nextTrackIndex']) ?? results.length;
    nextIndex = nextIndex.clamp(0, tracks.length);
    if (results.length > nextIndex) {
      results.removeRange(nextIndex, results.length);
    }

    final safeBatchSize = batchSize.clamp(1, maximumPilotBatchSize);
    final stopIndex = (nextIndex + safeBatchSize).clamp(0, tracks.length);
    metadata['matchingStatus'] = 'running';
    await _checkpoint(results, metadata, nextIndex, tracks.length);

    var sinceCheckpoint = 0;
    var stopped = false;
    while (nextIndex < stopIndex) {
      if (shouldStop?.call() ?? false) {
        stopped = true;
        break;
      }

      final source = tracks[nextIndex];
      Map<String, dynamic> result;
      if (excludedRows.contains(source['sourceRow']?.toString())) {
        result = _excludedResult(source);
      } else {
        try {
          result = await _matchOne(source);
        } catch (error) {
          result = {
            'sourceRow': source['sourceRow'],
            'sourceTitle': source['title']?.toString() ?? '',
            'sourceArtist': source['artist']?.toString() ?? '',
            'sourceAlbum': source['album']?.toString() ?? '',
            'sourceIsrc': source['isrc']?.toString() ?? '',
            'status': 'error',
            'score': 0.0,
            'error': error.toString(),
            'matchedAt': DateTime.now().toUtc().toIso8601String(),
          };
        }
      }

      // A network lookup can finish after the matching page has been
      // disposed. Do not checkpoint that result into a replacement import.
      if (shouldStop?.call() ?? false) {
        stopped = true;
        break;
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
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    if (stopped) return loadSnapshot();

    metadata['matchingStatus'] = nextIndex >= tracks.length
        ? 'complete'
        : 'paused';
    await _checkpoint(results, metadata, nextIndex, tracks.length);
    return _snapshot(tracks, results, metadata);
  }

  Future<Map<String, dynamic>> _matchOne(Map<String, dynamic> source) async {
    final title = source['title']?.toString().trim() ?? '';
    final artist = source['artist']?.toString().trim() ?? '';
    final album = source['album']?.toString().trim() ?? '';
    final isrc = source['isrc']?.toString().trim() ?? '';
    final durationMs = _asInt(source['durationMs']);
    final input = SpotifyMatchInput(
      title: title,
      artist: artist,
      album: album,
      isrc: isrc,
      durationMs: durationMs,
    );

    final candidates = <Map<String, dynamic>>[];
    final searchSources = <String>[];
    final sourceFailures = <String>[];

    try {
      final musicSongs = await _youtubeMusic.music
          .searchSongs('$artist $title', limit: 12)
          .timeout(_musicSearchTimeout);
      candidates.addAll(musicSongs.map(_musicSongCandidate));
      searchSources.add('youtube_music_songs');
    } catch (error) {
      sourceFailures.add('YouTube Music search failed: $error');
    }

    var evaluation = _evaluate(input, candidates);
    final firstMusicScore = evaluation.ranked.isEmpty
        ? 0.0
        : evaluation.ranked.first['score'] as double;
    final firstMusicAutomatic = evaluation.ranked.isNotEmpty &&
        evaluation.ranked.first['automaticEligible'] == true;

    if (!firstMusicAutomatic || firstMusicScore < automaticMatchThreshold) {
      try {
        final officialResults = await fetchSongsList(
          '$artist $title official audio'.trim(),
        ).timeout(_musicSearchTimeout);
        candidates.addAll(
          officialResults.whereType<Map>().map(Map<String, dynamic>.from),
        );
        searchSources.add('youtube_official_audio');
        evaluation = _evaluate(input, candidates);
      } catch (error) {
        sourceFailures.add('YouTube official-audio search failed: $error');
      }
    }

    final topScore = evaluation.ranked.isEmpty
        ? 0.0
        : evaluation.ranked.first['score'] as double;
    if (topScore < reviewThreshold) {
      try {
        final broadResults = await fetchSongsList(
          '$artist $title'.trim(),
        ).timeout(_musicSearchTimeout);
        candidates.addAll(
          broadResults.whereType<Map>().map(Map<String, dynamic>.from),
        );
        searchSources.add('youtube_broad_fallback');
        evaluation = _evaluate(input, candidates);
      } catch (error) {
        sourceFailures.add('YouTube broad fallback failed: $error');
      }
    }

    final best = evaluation.ranked.isEmpty ? null : evaluation.ranked.first;
    final bestScore = best?['score'] as double? ?? 0.0;
    final automaticEligible = best?['automaticEligible'] == true;
    final status = best == null
        ? 'unmatched'
        : automaticEligible && bestScore >= automaticMatchThreshold
        ? 'matched'
        : bestScore >= reviewThreshold
        ? 'needs_review'
        : 'unmatched';

    return {
      'sourceRow': source['sourceRow'],
      'sourceTitle': title,
      'sourceArtist': artist,
      'sourceAlbum': album,
      'sourceIsrc': isrc,
      'sourceDurationMs': durationMs,
      'status': status,
      'score': bestScore,
      'bestCandidate': best?['candidate'],
      'matchEvidence': best?['evidence'],
      'alternatives': evaluation.ranked
          .take(5)
          .map(
            (item) => {
              'score': item['score'],
              'candidate': item['candidate'],
              'evidence': item['evidence'],
            },
          )
          .toList(growable: false),
      'rejectedCandidates': evaluation.rejected.take(5).toList(growable: false),
      'unmatchedReason': status == 'unmatched'
          ? _unmatchedReason(evaluation)
          : null,
      'searchSources': searchSources,
      'sourceFailures': sourceFailures,
      'matchedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> _musicSongCandidate(MusicSong song) {
    final artist = song.artists.join(', ');
    return {
      'ytid': song.id,
      'title': song.title,
      'artist': artist,
      'artists': song.artists,
      'videoAuthor': song.artists.isEmpty ? artist : '${song.artists.first} - Topic',
      'album': song.album ?? '',
      'duration': song.duration?.inSeconds,
      'image': song.thumbnailUrl,
      'lowResImage': song.thumbnailUrl,
      'highResImage': song.thumbnailUrl,
      'isExplicit': song.explicit,
      'sourceType': 'youtube_music_song',
    };
  }

  _CandidateEvaluation _evaluate(
    SpotifyMatchInput input,
    Iterable<dynamic> candidates,
  ) {
    final seenIds = <String>{};
    final ranked = <Map<String, dynamic>>[];
    final rejected = <Map<String, dynamic>>[];

    for (final raw in candidates) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      final id = candidate['ytid']?.toString() ?? '';
      if (id.isEmpty || !seenIds.add(id)) continue;

      final evidence = SpotifyMatchScorer.score(input, candidate);
      final entry = {
        'score': evidence.score,
        'automaticEligible': evidence.automaticEligible,
        'candidate': candidate,
        'evidence': evidence.toJson(),
      };
      if (evidence.disqualified) {
        rejected.add(entry);
      } else {
        ranked.add(entry);
      }
    }

    ranked.sort(
      (left, right) => (right['score'] as double).compareTo(
        left['score'] as double,
      ),
    );
    rejected.sort((left, right) {
      final leftEvidence = Map<String, dynamic>.from(left['evidence'] as Map);
      final rightEvidence = Map<String, dynamic>.from(right['evidence'] as Map);
      final leftIdentity =
          (_asDouble(leftEvidence['titleScore']) ?? 0) +
          (_asDouble(leftEvidence['primaryArtistScore']) ?? 0);
      final rightIdentity =
          (_asDouble(rightEvidence['titleScore']) ?? 0) +
          (_asDouble(rightEvidence['primaryArtistScore']) ?? 0);
      return rightIdentity.compareTo(leftIdentity);
    });
    return _CandidateEvaluation(ranked: ranked, rejected: rejected);
  }

  static String _unmatchedReason(_CandidateEvaluation evaluation) {
    if (evaluation.ranked.isNotEmpty) {
      final best = evaluation.ranked.first;
      final score = ((best['score'] as double) * 100).round();
      return 'Best surviving candidate reached only $score% confidence.';
    }
    if (evaluation.rejected.isNotEmpty) {
      final evidence = Map<String, dynamic>.from(
        evaluation.rejected.first['evidence'] as Map,
      );
      final reasons = evidence['reasons'];
      if (reasons is List && reasons.isNotEmpty) {
        return reasons.map((reason) => reason.toString()).join(' • ');
      }
      return 'Every candidate failed the song identity safety checks.';
    }
    return 'No playable song candidates were returned by the available sources.';
  }

  Future<void> _checkpoint(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> metadata,
    int nextIndex,
    int totalTracks,
  ) async {
    metadata['matchingVersion'] = 3;
    metadata['nextTrackIndex'] = nextIndex;
    metadata['matchedCount'] = results.where(_isMatched).length;
    metadata['reviewCount'] = _count(results, 'needs_review');
    metadata['unmatchedCount'] = results.where(_isUnmatched).length;
    metadata['errorCount'] = _count(results, 'error');
    metadata['excludedCount'] = _count(results, 'excluded');
    metadata['pendingResolutionCount'] = results.where(_isPendingResolution).length;
    metadata['validTrackCount'] = totalTracks;
    metadata['lastMatchingCheckpointAt'] = DateTime.now()
        .toUtc()
        .toIso8601String();

    await Hive.box('user').putAll({
      'spotifyMatchResults': results,
      'spotifyImportMetadata': metadata,
    });
  }

  SpotifyMatchingSnapshot _snapshot(
    List<Map<String, dynamic>> tracks,
    List<Map<String, dynamic>> results,
    Map<String, dynamic> metadata,
  ) {
    final nextIndex = (_asInt(metadata['nextTrackIndex']) ?? results.length)
        .clamp(0, tracks.length);
    return SpotifyMatchingSnapshot(
      totalTracks: tracks.length,
      nextTrackIndex: nextIndex,
      matchedCount: results.where(_isMatched).length,
      reviewCount: _count(results, 'needs_review'),
      unmatchedCount: results.where(_isUnmatched).length,
      errorCount: _count(results, 'error'),
      excludedCount: _count(results, 'excluded'),
      pendingResolutionCount: results.where(_isPendingResolution).length,
      status: metadata['matchingStatus']?.toString() ?? 'not_started',
      recentResults: results.reversed.take(10).toList(growable: false),
    );
  }

  static bool _isMatched(Map<String, dynamic> result) {
    final status = result['status'];
    return status == 'matched' || status == 'manually_matched';
  }

  static bool _isUnmatched(Map<String, dynamic> result) {
    final status = result['status'];
    return status == 'unmatched' || status == 'manual_unmatched';
  }

  static bool _isPendingResolution(Map<String, dynamic> result) {
    final status = result['status'];
    return status == 'needs_review' ||
        status == 'unmatched' ||
        status == 'manual_unmatched' ||
        status == 'error';
  }

  static int _count(List<Map<String, dynamic>> results, String status) {
    return results.where((result) => result['status'] == status).length;
  }

  static Set<String> _readExcludedRows(Box box) {
    return (box.get('spotifyExcludedImportRows') as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
  }

  static Map<String, dynamic> _excludedResult(Map<String, dynamic> source) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    return {
      'sourceRow': source['sourceRow'],
      'sourceTitle': source['title']?.toString() ?? '',
      'sourceArtist': source['artist']?.toString() ?? '',
      'sourceAlbum': source['album']?.toString() ?? '',
      'sourceIsrc': source['isrc']?.toString() ?? '',
      'sourceDurationMs': _asInt(source['durationMs']),
      'status': 'excluded',
      'score': 0.0,
      'bestCandidate': null,
      'matchEvidence': null,
      'alternatives': <Map<String, dynamic>>[],
      'reviewDecision': 'excluded_from_import',
      'excludedAt': timestamp,
      'reviewedAt': timestamp,
    };
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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

class _CandidateEvaluation {
  const _CandidateEvaluation({required this.ranked, required this.rejected});

  final List<Map<String, dynamic>> ranked;
  final List<Map<String, dynamic>> rejected;
}
