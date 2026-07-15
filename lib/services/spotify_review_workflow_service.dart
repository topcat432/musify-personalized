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

class SpotifyRescueProgress {
  const SpotifyRescueProgress({
    required this.processed,
    required this.total,
    required this.promotedToStrong,
    required this.promotedToReview,
    required this.stillUnmatched,
    required this.errors,
    required this.finished,
  });

  final int processed;
  final int total;
  final int promotedToStrong;
  final int promotedToReview;
  final int stillUnmatched;
  final int errors;
  final bool finished;

  double get fraction => total == 0 ? 1 : processed / total;
}

class SpotifyResolutionResult {
  const SpotifyResolutionResult({
    required this.duplicatesApplied,
    required this.remainingUnresolved,
  });

  final int duplicatesApplied;
  final int remainingUnresolved;
}

class SpotifyReviewCluster {
  const SpotifyReviewCluster({
    required this.key,
    required this.label,
    required this.count,
    required this.safeForBulkApproval,
  });

  final String key;
  final String label;
  final int count;
  final bool safeForBulkApproval;
}

abstract interface class SpotifyReviewSprintDataSource {
  Future<List<Map<String, dynamic>>> loadUnresolvedItems();

  Future<SpotifyResolutionResult> resolveItem({
    required Map<String, dynamic> item,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  });

  Future<SpotifyResolutionResult> excludeItem({
    required Map<String, dynamic> item,
  });

  Future<int> bulkApproveCluster({
    required String key,
    required String importSessionId,
  });
}

class SpotifyReviewWorkflowService implements SpotifyReviewSprintDataSource {
  const SpotifyReviewWorkflowService();

  static const String importSessionItemKey = '_spotifyImportSessionId';
  static const double _automaticThreshold = 0.86;
  static const double _reviewThreshold = 0.58;
  static const Duration _searchTimeout = Duration(seconds: 18);
  static final YoutubeMusicExplode _youtubeMusic = YoutubeMusicExplode();

  @override
  Future<List<Map<String, dynamic>>> loadUnresolvedItems() async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'));
    final sessionId = _sessionId(_readMap(box.get('spotifyImportMetadata')));
    final items = results
        .where(isPendingResolution)
        .map(
          (item) => Map<String, dynamic>.from(item)
            ..[importSessionItemKey] = sessionId,
        )
        .toList(growable: true)
      ..sort(_reviewPriorityCompare);
    return items;
  }

  Future<List<SpotifyReviewCluster>> loadClusters() async {
    final items = await loadUnresolvedItems();
    final counts = <String, int>{};
    final labels = <String, String>{};
    final safe = <String, bool>{};

    for (final item in items) {
      final key = clusterKey(item);
      counts[key] = (counts[key] ?? 0) + 1;
      labels[key] = clusterLabel(item);
      safe[key] = (safe[key] ?? true) && isSafeClusterItem(item);
    }

    final clusters = counts.entries
        .map(
          (entry) => SpotifyReviewCluster(
            key: entry.key,
            label: labels[entry.key] ?? 'Other unresolved matches',
            count: entry.value,
            safeForBulkApproval: safe[entry.key] ?? false,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.count.compareTo(left.count));
    return clusters;
  }

  Future<SpotifyRescueProgress> runRescuePass({
    bool Function()? shouldCancel,
    bool Function()? shouldPause,
    void Function(SpotifyRescueProgress progress)? onProgress,
  }) async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final importSessionId = _sessionId(metadata);
    final targetIndexes = <int>[];

    for (var index = 0; index < results.length; index++) {
      final status = results[index]['status'];
      if (status == 'needs_review' || status == 'unmatched' || status == 'error') {
        targetIndexes.add(index);
      }
    }

    var processed = 0;
    var promotedToStrong = 0;
    var promotedToReview = 0;
    var stillUnmatched = 0;
    var errors = 0;
    var sinceCheckpoint = 0;
    var stopped = false;

    for (final index in targetIndexes) {
      if (shouldCancel?.call() ?? false) {
        stopped = true;
        break;
      }
      if (shouldPause?.call() ?? false) {
        stopped = true;
        break;
      }

      final current = Map<String, dynamic>.from(results[index]);
      var updated = current;
      try {
        if (current['status'] == 'needs_review' && isSafeClusterItem(current)) {
          updated = _acceptTopAlternative(
            current,
            decision: 'rescue_safe_evidence',
          );
        } else if (current['status'] == 'needs_review') {
          updated = current;
        } else {
          updated = await _rescueOne(current);
        }
      } catch (error) {
        errors++;
        updated = Map<String, dynamic>.from(current)
          ..['status'] = 'error'
          ..['error'] = 'Rescue pass failed: $error'
          ..['rescueAttemptedAt'] = DateTime.now().toUtc().toIso8601String();
      }

      // A rescue lookup can return after its page was disposed. Cancellation
      // discards that result; a user pause still keeps the completed item.
      if (shouldCancel?.call() ?? false) {
        stopped = true;
        break;
      }

      final previousStatus = current['status'];
      final nextStatus = updated['status'];
      if (nextStatus == 'matched' && previousStatus != 'matched') {
        promotedToStrong++;
      } else if (nextStatus == 'needs_review' &&
          previousStatus != 'needs_review') {
        promotedToReview++;
      } else if (nextStatus == 'unmatched') {
        stillUnmatched++;
      }
      results[index] = updated;

      processed++;
      sinceCheckpoint++;
      final pauseRequested = shouldPause?.call() ?? false;
      if (sinceCheckpoint >= 5 || pauseRequested) {
        if (!await _checkpoint(
          results,
          metadata,
          expectedSessionId: importSessionId,
        )) {
          stopped = true;
          break;
        }
        sinceCheckpoint = 0;
      }

      onProgress?.call(
        SpotifyRescueProgress(
          processed: processed,
          total: targetIndexes.length,
          promotedToStrong: promotedToStrong,
          promotedToReview: promotedToReview,
          stillUnmatched: stillUnmatched,
          errors: errors,
          finished: false,
        ),
      );
      if (pauseRequested) {
        stopped = true;
        break;
      }
    }

    if (!stopped || sinceCheckpoint > 0) {
      stopped = !await _checkpoint(
        results,
        metadata,
        expectedSessionId: importSessionId,
      );
    }
    final progress = SpotifyRescueProgress(
      processed: processed,
      total: targetIndexes.length,
      promotedToStrong: promotedToStrong,
      promotedToReview: promotedToReview,
      stillUnmatched: stillUnmatched,
      errors: errors,
      finished: !stopped && processed >= targetIndexes.length,
    );
    onProgress?.call(progress);
    return progress;
  }

  @override
  Future<SpotifyResolutionResult> resolveItem({
    required Map<String, dynamic> item,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  }) async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final sourceRow = item['sourceRow']?.toString();
    final index = results.indexWhere(
      (candidate) => candidate['sourceRow']?.toString() == sourceRow,
    );
    if (index == -1) {
      throw StateError('The imported track is no longer in the match list.');
    }
    final importSessionId = validateCurrentItem(
      item: item,
      currentResult: results[index],
      metadata: metadata,
    );

    final updated = Map<String, dynamic>.from(results[index]);
    var duplicatesApplied = 0;
    if (accept) {
      final alternative = selectedAlternative ?? _topAlternative(updated);
      final candidate = alternative?['candidate'];
      if (candidate is! Map) {
        throw StateError('No selectable source is available for this track.');
      }
      updated
        ..['status'] = 'manually_matched'
        ..['score'] = _asDouble(alternative?['score']) ?? 0.0
        ..['bestCandidate'] = Map<String, dynamic>.from(candidate)
        ..['matchEvidence'] = alternative?['evidence']
        ..['reviewDecision'] = 'review_sprint_accept'
        ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
      results[index] = updated;
      duplicatesApplied = _applyExactIsrcDuplicates(
        results,
        sourceIndex: index,
        selectedAlternative: alternative!,
      );
    } else {
      updated
        ..['status'] = 'manual_unmatched'
        ..['score'] = 0.0
        ..['bestCandidate'] = null
        ..['matchEvidence'] = null
        ..['reviewDecision'] = 'review_sprint_no_match'
        ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
      results[index] = updated;
    }

    await _checkpoint(
      results,
      metadata,
      expectedSessionId: importSessionId,
    );
    return SpotifyResolutionResult(
      duplicatesApplied: duplicatesApplied,
      remainingUnresolved: results.where(isPendingResolution).length,
    );
  }

  @override
  Future<SpotifyResolutionResult> excludeItem({
    required Map<String, dynamic> item,
  }) async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    final sourceRow = item['sourceRow']?.toString();
    if (sourceRow == null || sourceRow.isEmpty) {
      throw StateError('The imported track has no stable source row.');
    }
    final index = results.indexWhere(
      (candidate) => candidate['sourceRow']?.toString() == sourceRow,
    );
    if (index == -1) {
      throw StateError('The imported track is no longer in the match list.');
    }
    final importSessionId = validateCurrentItem(
      item: item,
      currentResult: results[index],
      metadata: metadata,
    );

    final excludedRows =
        (box.get('spotifyExcludedImportRows') as List? ?? const [])
            .map((value) => value.toString())
            .toSet()
          ..add(sourceRow);

    results[index] = Map<String, dynamic>.from(results[index])
      ..['status'] = 'excluded'
      ..['score'] = 0.0
      ..['bestCandidate'] = null
      ..['matchEvidence'] = null
      ..['reviewDecision'] = 'excluded_from_import'
      ..['excludedAt'] = DateTime.now().toUtc().toIso8601String()
      ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();

    await _checkpoint(
      results,
      metadata,
      expectedSessionId: importSessionId,
      excludedRows: excludedRows.toList(growable: false)..sort(),
    );
    return SpotifyResolutionResult(
      duplicatesApplied: 0,
      remainingUnresolved: results.where(isPendingResolution).length,
    );
  }

  @override
  Future<int> bulkApproveCluster({
    required String key,
    required String importSessionId,
  }) async {
    final box = Hive.box('user');
    final results = _readMaps(box.get('spotifyMatchResults'));
    final metadata = _readMap(box.get('spotifyImportMetadata'));
    if (importSessionId.isEmpty || _sessionId(metadata) != importSessionId) {
      throw StateError(
        'This review belongs to an older import. Reload the review queue.',
      );
    }
    var approved = 0;

    for (var index = 0; index < results.length; index++) {
      final item = results[index];
      if (item['status'] != 'needs_review' ||
          clusterKey(item) != key ||
          !isSafeClusterItem(item)) {
        continue;
      }
      results[index] = _acceptTopAlternative(
        item,
        decision: 'audited_cluster_approval',
      );
      approved++;
    }

    if (approved > 0 &&
        !await _checkpoint(
          results,
          metadata,
          expectedSessionId: importSessionId,
        )) {
      throw StateError(
        'The import changed before the group could be saved. Reload the review queue.',
      );
    }
    return approved;
  }

  static String clusterKey(Map<String, dynamic> item) {
    final alternative = _topAlternative(item);
    final candidate = alternative?['candidate'] is Map
        ? Map<String, dynamic>.from(alternative!['candidate'] as Map)
        : <String, dynamic>{};
    final evidence = alternative?['evidence'] is Map
        ? Map<String, dynamic>.from(alternative!['evidence'] as Map)
        : _readMap(item['matchEvidence']);
    final sourceType = candidate['sourceType']?.toString() ?? 'none';
    final titleTier = _tier(_asDouble(evidence['titleScore']));
    final artistTier = _tier(_asDouble(evidence['primaryArtistScore']));
    final albumTier = _optionalTier(_asDouble(evidence['albumScore']));
    final durationTier = _optionalTier(_asDouble(evidence['durationScore']));
    final alternate = _hasNegativeVersionSignal(evidence) ? 'version-risk' : 'normal-version';
    return '$sourceType|$titleTier|$artistTier|$albumTier|$durationTier|$alternate';
  }

  static String clusterLabel(Map<String, dynamic> item) {
    final alternative = _topAlternative(item);
    final candidate = alternative?['candidate'] is Map
        ? Map<String, dynamic>.from(alternative!['candidate'] as Map)
        : <String, dynamic>{};
    final evidence = alternative?['evidence'] is Map
        ? Map<String, dynamic>.from(alternative!['evidence'] as Map)
        : _readMap(item['matchEvidence']);
    final source = candidate['sourceType'] == 'youtube_music_song'
        ? 'YouTube Music song'
        : candidate.isEmpty
        ? 'No candidate'
        : 'YouTube fallback';
    final title = (_asDouble(evidence['titleScore']) ?? 0) >= 0.95
        ? 'exact title'
        : 'close title';
    final artist = (_asDouble(evidence['primaryArtistScore']) ?? 0) >= 0.90
        ? 'matching artist'
        : 'artist needs care';
    final album = (_asDouble(evidence['albumScore']) ?? 0.5) >= 0.90
        ? 'matching album'
        : 'album uncertain';
    final version = _hasNegativeVersionSignal(evidence)
        ? 'version risk'
        : 'normal version';
    return '$source • $title • $artist • $album • $version';
  }

  static bool isSafeClusterItem(Map<String, dynamic> item) {
    if (item['status'] != 'needs_review') return false;
    final alternative = _topAlternative(item);
    if (alternative == null) return false;
    final candidate = alternative['candidate'];
    final evidenceRaw = alternative['evidence'];
    if (candidate is! Map || evidenceRaw is! Map) return false;
    final candidateMap = Map<String, dynamic>.from(candidate);
    final evidence = Map<String, dynamic>.from(evidenceRaw);
    final sourceIsReliable = SpotifyMatchScorer.isReliableSource(candidateMap);
    final titleScore = _asDouble(evidence['titleScore']) ?? 0;
    final artistScore = _asDouble(evidence['primaryArtistScore']) ?? 0;
    final albumScore = _asDouble(evidence['albumScore']) ?? 0.5;
    final durationScore = _asDouble(evidence['durationScore']) ?? 0.5;
    final score = _asDouble(alternative['score']) ?? 0;
    final albumAvailable = (item['sourceAlbum']?.toString().trim().isNotEmpty ?? false) &&
        (candidateMap['album']?.toString().trim().isNotEmpty ?? false);
    final durationAvailable = item['sourceDurationMs'] != null && candidateMap['duration'] != null;

    return sourceIsReliable &&
        titleScore >= 0.98 &&
        artistScore >= 0.95 &&
        (!albumAvailable || albumScore >= 0.90) &&
        (!durationAvailable || durationScore >= 0.90) &&
        score >= 0.80 &&
        !_hasNegativeVersionSignal(evidence);
  }

  Future<Map<String, dynamic>> _rescueOne(Map<String, dynamic> item) async {
    final title = item['sourceTitle']?.toString().trim() ?? '';
    final artist = item['sourceArtist']?.toString().trim() ?? '';
    final album = item['sourceAlbum']?.toString().trim() ?? '';
    final input = SpotifyMatchInput(
      title: title,
      artist: artist,
      album: album,
      isrc: item['sourceIsrc']?.toString() ?? '',
      durationMs: _asInt(item['sourceDurationMs']),
    );
    final candidates = <Map<String, dynamic>>[];
    final queries = <String>{
      '$artist $title $album'.trim(),
      '$title $album $artist'.trim(),
      '$artist $title official audio'.trim(),
    }.where((query) => query.isNotEmpty);

    for (final query in queries.take(2)) {
      try {
        final songs = await _youtubeMusic.music
            .searchSongs(query, limit: 20)
            .timeout(_searchTimeout);
        candidates.addAll(songs.map(_musicSongCandidate));
      } catch (_) {
        // The ordinary YouTube fallback below may still recover the track.
      }
    }

    try {
      final fallback = await fetchSongsList(
        '$artist $title $album official audio'.trim(),
      ).timeout(_searchTimeout);
      candidates.addAll(
        fallback.whereType<Map>().map(Map<String, dynamic>.from),
      );
    } catch (_) {
      // Return any structured candidates already found instead of leaving
      // the review UI blocked on an unbounded ordinary-YouTube request.
    }
    final ranked = _rankCandidates(input, candidates);
    final best = ranked.isEmpty ? null : ranked.first;
    final score = _asDouble(best?['score']) ?? 0;
    final automatic = best?['automaticEligible'] == true;
    final status = best == null
        ? 'unmatched'
        : automatic && score >= _automaticThreshold
        ? 'matched'
        : score >= _reviewThreshold
        ? 'needs_review'
        : 'unmatched';

    return Map<String, dynamic>.from(item)
      ..['status'] = status
      ..['score'] = score
      ..['bestCandidate'] = best?['candidate']
      ..['matchEvidence'] = best?['evidence']
      ..['alternatives'] = ranked.take(5).map((entry) => {
            'score': entry['score'],
            'candidate': entry['candidate'],
            'evidence': entry['evidence'],
          }).toList(growable: false)
      ..['unmatchedReason'] = status == 'unmatched'
          ? best == null
              ? 'The rescue searches returned no safe song candidates.'
              : 'The best rescue candidate reached only ${(score * 100).round()}% confidence.'
          : null
      ..['rescueAttemptedAt'] = DateTime.now().toUtc().toIso8601String()
      ..['reviewDecision'] = status == 'matched' ? 'rescue_automatic' : null;
  }

  static List<Map<String, dynamic>> _rankCandidates(
    SpotifyMatchInput input,
    Iterable<dynamic> candidates,
  ) {
    final seen = <String>{};
    final ranked = <Map<String, dynamic>>[];
    for (final raw in candidates) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      final id = candidate['ytid']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      final evidence = SpotifyMatchScorer.score(input, candidate);
      if (evidence.disqualified) continue;
      ranked.add({
        'score': evidence.score,
        'automaticEligible': evidence.automaticEligible,
        'candidate': candidate,
        'evidence': evidence.toJson(),
      });
    }
    ranked.sort(
      (left, right) => (_asDouble(right['score']) ?? 0)
          .compareTo(_asDouble(left['score']) ?? 0),
    );
    return ranked;
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

  static Map<String, dynamic> _acceptTopAlternative(
    Map<String, dynamic> item, {
    required String decision,
  }) {
    final alternative = _topAlternative(item);
    if (alternative == null || alternative['candidate'] is! Map) return item;
    return Map<String, dynamic>.from(item)
      ..['status'] = 'matched'
      ..['score'] = _asDouble(alternative['score']) ?? 0.0
      ..['bestCandidate'] = Map<String, dynamic>.from(alternative['candidate'] as Map)
      ..['matchEvidence'] = alternative['evidence']
      ..['reviewDecision'] = decision
      ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
  }

  static int _applyExactIsrcDuplicates(
    List<Map<String, dynamic>> results, {
    required int sourceIndex,
    required Map<String, dynamic> selectedAlternative,
  }) {
    final sourceIsrc = _normalizeIsrc(results[sourceIndex]['sourceIsrc']?.toString() ?? '');
    if (sourceIsrc.isEmpty) return 0;
    final candidate = selectedAlternative['candidate'];
    if (candidate is! Map) return 0;
    var applied = 0;
    for (var index = 0; index < results.length; index++) {
      if (index == sourceIndex || !isPendingResolution(results[index])) continue;
      final otherIsrc = _normalizeIsrc(results[index]['sourceIsrc']?.toString() ?? '');
      if (otherIsrc != sourceIsrc) continue;
      results[index] = Map<String, dynamic>.from(results[index])
        ..['status'] = 'manually_matched'
        ..['score'] = _asDouble(selectedAlternative['score']) ?? 0.0
        ..['bestCandidate'] = Map<String, dynamic>.from(candidate)
        ..['matchEvidence'] = selectedAlternative['evidence']
        ..['reviewDecision'] = 'exact_isrc_duplicate'
        ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
      applied++;
    }
    return applied;
  }

  static Map<String, dynamic>? _topAlternative(Map<String, dynamic> item) {
    final raw = item['alternatives'];
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    final candidate = item['bestCandidate'];
    if (candidate is! Map) return null;
    return {
      'score': item['score'] ?? 0.0,
      'candidate': Map<String, dynamic>.from(candidate),
      'evidence': _readMap(item['matchEvidence']),
    };
  }

  Future<bool> _checkpoint(
    List<Map<String, dynamic>> results,
    Map<String, dynamic> metadata, {
    String? expectedSessionId,
    List<String>? excludedRows,
  }) async {
    final box = Hive.box('user');
    if (expectedSessionId != null &&
        _sessionId(_readMap(box.get('spotifyImportMetadata'))) !=
            expectedSessionId) {
      return false;
    }
    metadata
      ..['matchedCount'] = results.where(_isMatched).length
      ..['reviewCount'] = results.where((item) => item['status'] == 'needs_review').length
      ..['unmatchedCount'] = results.where(_isUnmatched).length
      ..['errorCount'] = results.where((item) => item['status'] == 'error').length
      ..['excludedCount'] = results.where(isExcluded).length
      ..['pendingResolutionCount'] = results.where(isPendingResolution).length
      ..['lastMatchingCheckpointAt'] = DateTime.now().toUtc().toIso8601String();
    await box.putAll({
      'spotifyMatchResults': results,
      'spotifyImportMetadata': metadata,
      if (excludedRows != null) 'spotifyExcludedImportRows': excludedRows,
    });
    return true;
  }

  static String _sessionId(Map<String, dynamic> metadata) =>
      metadata['importSessionId']?.toString() ??
      metadata['importedAt']?.toString() ??
      metadata['fileName']?.toString() ??
      '';

  static String validateCurrentItem({
    required Map<String, dynamic> item,
    required Map<String, dynamic> currentResult,
    required Map<String, dynamic> metadata,
  }) {
    final expectedSessionId = item[importSessionItemKey]?.toString() ?? '';
    final currentSessionId = _sessionId(metadata);
    if (expectedSessionId != currentSessionId ||
        !_sameSourceIdentity(item, currentResult)) {
      throw StateError(
        'This review belongs to an older import. Reload the review queue.',
      );
    }
    return currentSessionId;
  }

  static bool _sameSourceIdentity(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    const keys = <String>[
      'sourceRow',
      'sourceTitle',
      'sourceArtist',
      'sourceAlbum',
      'sourceIsrc',
      'sourceDurationMs',
    ];
    return keys.every(
      (key) =>
          left[key]?.toString().trim() == right[key]?.toString().trim(),
    );
  }

  static int _reviewPriorityCompare(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    int priority(Map<String, dynamic> item) => switch (item['status']) {
          'needs_review' => 0,
          'unmatched' => 1,
          'manual_unmatched' => 2,
          'error' => 3,
          _ => 4,
        };
    final statusCompare = priority(left).compareTo(priority(right));
    if (statusCompare != 0) return statusCompare;
    final scoreCompare = (_asDouble(right['score']) ?? 0)
        .compareTo(_asDouble(left['score']) ?? 0);
    if (scoreCompare != 0) return scoreCompare;
    return (_asInt(left['sourceRow']) ?? 0).compareTo(_asInt(right['sourceRow']) ?? 0);
  }

  static bool isPendingResolution(Map<String, dynamic> item) {
    final status = item['status'];
    return status == 'needs_review' ||
        status == 'unmatched' ||
        status == 'manual_unmatched' ||
        status == 'error';
  }

  static bool isExcluded(Map<String, dynamic> item) {
    return item['status'] == 'excluded';
  }

  static bool _isMatched(Map<String, dynamic> item) {
    return item['status'] == 'matched' || item['status'] == 'manually_matched';
  }

  static bool _isUnmatched(Map<String, dynamic> item) {
    return item['status'] == 'unmatched' || item['status'] == 'manual_unmatched';
  }

  static bool _hasNegativeVersionSignal(Map<String, dynamic> evidence) {
    final reasons = evidence['reasons'];
    if (reasons is! List) return false;
    final joined = reasons.map((reason) => reason.toString().toLowerCase()).join(' ');
    return joined.contains('alternate version') ||
        joined.contains('different mastering') ||
        joined.contains('compilation') ||
        joined.contains('too weak') ||
        joined.contains('rejected');
  }

  static String _tier(double? value) {
    final score = value ?? 0;
    if (score >= 0.98) return 'exact';
    if (score >= 0.90) return 'strong';
    if (score >= 0.75) return 'close';
    return 'weak';
  }

  static String _optionalTier(double? value) {
    final score = value ?? 0.5;
    if ((score - 0.5).abs() < 0.001) return 'missing';
    return _tier(score);
  }

  static String _normalizeIsrc(String value) {
    return value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
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
