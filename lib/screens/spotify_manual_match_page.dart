/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/spotify_manual_source_service.dart';
import 'package:musify/services/spotify_match_scoring.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';
import 'package:musify/widgets/personalized_ui.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

class SpotifyManualMatchPage extends StatefulWidget {
  const SpotifyManualMatchPage({required this.item, super.key});

  final Map<String, dynamic> item;

  @override
  State<SpotifyManualMatchPage> createState() => _SpotifyManualMatchPageState();
}

class _SpotifyManualMatchPageState extends State<SpotifyManualMatchPage> {
  static final YoutubeMusicExplode _youtubeMusic = YoutubeMusicExplode();
  static const SpotifyManualSourceService _manualSourceService =
      SpotifyManualSourceService();
  static const Duration _timeout = Duration(seconds: 18);
  static const Duration _previewLength = Duration(seconds: 30);

  final AudioPlayer _previewPlayer = AudioPlayer();
  late final TextEditingController _queryController;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _previewTimer;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _saving = false;
  bool _previewPlaying = false;
  String? _previewingId;
  String? _previewLoadingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final artist = widget.item['sourceArtist']?.toString().trim() ?? '';
    final title = widget.item['sourceTitle']?.toString().trim() ?? '';
    _queryController = TextEditingController(text: '$artist $title'.trim());
    _playerStateSubscription = _previewPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      setState(() {
        _previewPlaying = state.playing && !completed;
        if (completed) {
          _previewingId = null;
          _previewLoadingId = null;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _playerStateSubscription?.cancel();
    unawaited(_previewPlayer.dispose());
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;

    await _stopPreview();
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final exactVideoId = SpotifyManualSourceService.parseExactVideoId(query);
      if (exactVideoId != null) {
        final candidate = await _manualSourceService
            .loadExactVideo(query)
            .timeout(_timeout);
        final streamUrl = await fetchSongStreamUrl(
          exactVideoId,
          false,
        ).timeout(_timeout);
        if (streamUrl == null || streamUrl.isEmpty) {
          throw StateError(
            'That video exists, but Musify could not find playable audio for it.',
          );
        }
        final result = _rankCandidate(candidate, isDirectUrl: true);
        if (!mounted) return;
        setState(() => _results = [result]);
        return;
      }

      final candidates = <Map<String, dynamic>>[];
      final seen = <String>{};

      void addCandidate(Map<String, dynamic> candidate) {
        final id = candidate['ytid']?.toString() ?? '';
        if (id.isNotEmpty && seen.add(id)) candidates.add(candidate);
      }

      try {
        final songs = await _youtubeMusic.music
            .searchSongs(query, limit: 20)
            .timeout(_timeout);
        for (final song in songs) {
          final artist = song.artists.join(', ');
          addCandidate({
            'ytid': song.id,
            'title': song.title,
            'artist': artist,
            'artists': song.artists,
            'videoAuthor': song.artists.isEmpty
                ? artist
                : '${song.artists.first} - Topic',
            'album': song.album ?? '',
            'duration': song.duration?.inSeconds,
            'image': song.thumbnailUrl,
            'lowResImage': song.thumbnailUrl,
            'highResImage': song.thumbnailUrl,
            'isExplicit': song.explicit,
            'sourceType': 'youtube_music_song',
          });
        }
      } catch (_) {
        // Ordinary YouTube fallback below can still succeed.
      }

      final youtubeResults = await fetchSongsList(query);
      for (final raw in youtubeResults.whereType<Map>()) {
        addCandidate(Map<String, dynamic>.from(raw));
      }

      final ranked = <Map<String, dynamic>>[];
      for (final candidate in candidates) {
        ranked.add(_rankCandidate(candidate));
      }
      ranked.sort(
        (left, right) =>
            (right['score'] as double).compareTo(left['score'] as double),
      );

      if (!mounted) return;
      setState(() => _results = ranked.take(30).toList(growable: false));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Map<String, dynamic> _rankCandidate(
    Map<String, dynamic> candidate, {
    bool isDirectUrl = false,
  }) {
    final input = SpotifyMatchInput(
      title: widget.item['sourceTitle']?.toString() ?? '',
      artist: widget.item['sourceArtist']?.toString() ?? '',
      album: widget.item['sourceAlbum']?.toString() ?? '',
      isrc: widget.item['sourceIsrc']?.toString() ?? '',
      durationMs: _asInt(widget.item['sourceDurationMs']),
    );
    final evidence = SpotifyMatchScorer.score(input, candidate);
    return {
      'candidate': candidate,
      'score': evidence.score,
      'evidence': evidence.toJson(),
      'isDirectUrl': isDirectUrl,
    };
  }

  Future<void> _togglePreview(Map<String, dynamic> result) async {
    if (_saving) return;
    final candidate = result['candidate'];
    if (candidate is! Map) return;
    final songId = candidate['ytid']?.toString() ?? '';
    if (songId.isEmpty || _previewLoadingId == songId) return;

    if (_previewingId == songId) {
      if (_previewPlaying) {
        _previewTimer?.cancel();
        await _previewPlayer.pause();
      } else {
        await _previewPlayer.play();
        _armPreviewTimer();
      }
      return;
    }

    await _stopPreview();
    if (!mounted) return;
    setState(() {
      _previewLoadingId = songId;
      _error = null;
    });

    try {
      final streamUrl = await fetchSongStreamUrl(songId, false);
      if (streamUrl == null || streamUrl.isEmpty) {
        throw StateError('No playable audio stream was found for this result.');
      }

      await _previewPlayer.setUrl(streamUrl);
      final durationSeconds = _asInt(candidate['duration']);
      final previewStart = durationSeconds != null && durationSeconds > 75
          ? const Duration(seconds: 20)
          : Duration.zero;
      if (previewStart > Duration.zero) {
        await _previewPlayer.seek(previewStart);
      }
      if (!mounted) return;
      setState(() {
        _previewingId = songId;
        _previewLoadingId = null;
      });
      await _previewPlayer.play();
      _armPreviewTimer();
    } catch (error) {
      await _stopPreview();
      if (!mounted) return;
      setState(() => _error = 'Preview failed: $error');
    }
  }

  void _armPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewLength, () {
      unawaited(_stopPreview());
    });
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    try {
      await _previewPlayer.stop();
    } catch (_) {
      // A failed or already-disposed player does not need further recovery.
    }
    if (!mounted) return;
    setState(() {
      _previewingId = null;
      _previewLoadingId = null;
      _previewPlaying = false;
    });
  }

  Future<void> _save(Map<String, dynamic> result) async {
    if (_saving) return;
    final candidate = result['candidate'];
    if (candidate is! Map) return;

    await _stopPreview();
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final box = Hive.box('user');
      final results = _readMaps(box.get('spotifyMatchResults'));
      final metadata = _readMap(box.get('spotifyImportMetadata'));
      final sourceRow = widget.item['sourceRow']?.toString();
      final index = results.indexWhere(
        (item) => item['sourceRow']?.toString() == sourceRow,
      );
      if (index == -1) {
        throw StateError('The imported track is no longer in the match list.');
      }

      final updated = Map<String, dynamic>.from(results[index])
        ..['status'] = 'manually_matched'
        ..['score'] = result['score']
        ..['bestCandidate'] = Map<String, dynamic>.from(candidate)
        ..['matchEvidence'] = result['evidence']
        ..['reviewDecision'] = result['isDirectUrl'] == true
            ? 'manual_url'
            : 'manual_search'
        ..['manualSearchQuery'] = _queryController.text.trim()
        ..['manualSourceUrl'] = result['isDirectUrl'] == true
            ? _queryController.text.trim()
            : null
        ..['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
      results[index] = updated;

      metadata
        ..['matchedCount'] = results.where(_isMatched).length
        ..['reviewCount'] = results
            .where((item) => item['status'] == 'needs_review')
            .length
        ..['unmatchedCount'] = results.where(_isUnmatched).length
        ..['errorCount'] = results
            .where((item) => item['status'] == 'error')
            .length
        ..['pendingResolutionCount'] = results
            .where(SpotifyReviewWorkflowService.isPendingResolution)
            .length
        ..['lastMatchingCheckpointAt'] = DateTime.now()
            .toUtc()
            .toIso8601String();

      await addOrUpdateData<List>('user', 'spotifyMatchResults', results);
      await addOrUpdateData<Map<String, dynamic>>(
        'user',
        'spotifyImportMetadata',
        metadata,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceTitle =
        widget.item['sourceTitle']?.toString() ?? 'Unknown track';
    final sourceArtist = widget.item['sourceArtist']?.toString() ?? '';
    final sourceAlbum = widget.item['sourceAlbum']?.toString() ?? '';
    final sourceDescription = sourceAlbum.isEmpty
        ? sourceArtist
        : '$sourceArtist · $sourceAlbum';

    return Scaffold(
      appBar: AppBar(title: const Text('Manual search')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          PersonalizedHero(
            eyebrow: 'Finding a source for',
            icon: Icons.manage_search_rounded,
            title: sourceTitle,
            description: sourceDescription.isEmpty
                ? 'Search by title, artist, album, or recording version.'
                : sourceDescription,
          ),
          const SizedBox(height: 24),
          const PersonalizedSectionHeading(
            title: 'Search YouTube',
            description:
                'Search freely by words, or paste a YouTube or YouTube Music video link to inspect that exact upload.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search terms or YouTube video link',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _searching ? null : _search,
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            PersonalizedStatusBanner(
              tone: PersonalizedStatusTone.error,
              title: 'Search interrupted',
              message: _error!,
            ),
          ],
          const SizedBox(height: 22),
          if (_searching)
            const _ManualSearchLoading()
          else if (_results.isEmpty)
            const PersonalizedEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No YouTube results',
              description:
                  'Try different words or paste the exact video link you found.',
            )
          else ...[
            PersonalizedSectionHeading(
              title: 'Possible matches',
              description:
                  'Results are not hidden by automatic confidence rules. Preview and choose the recording yourself.',
              trailing: Text(
                '${_results.length}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            for (final result in _results) ...[
              _ManualResultTile(
                result: result,
                enabled: !_saving,
                previewLoading:
                    _previewLoadingId ==
                    (result['candidate'] as Map)['ytid']?.toString(),
                previewPlaying:
                    _previewPlaying &&
                    _previewingId ==
                        (result['candidate'] as Map)['ytid']?.toString(),
                onPreview: () => _togglePreview(result),
                onUse: () => _save(result),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  static bool _isMatched(Map<String, dynamic> item) {
    return item['status'] == 'matched' || item['status'] == 'manually_matched';
  }

  static bool _isUnmatched(Map<String, dynamic> item) {
    return item['status'] == 'unmatched' ||
        item['status'] == 'manual_unmatched';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _readMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
  }
}

class _ManualSearchLoading extends StatelessWidget {
  const _ManualSearchLoading();

  @override
  Widget build(BuildContext context) {
    return const PersonalizedSurface(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Searching YouTube Music first, then checking YouTube…',
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualResultTile extends StatelessWidget {
  const _ManualResultTile({
    required this.result,
    required this.enabled,
    required this.previewLoading,
    required this.previewPlaying,
    required this.onPreview,
    required this.onUse,
  });

  final Map<String, dynamic> result;
  final bool enabled;
  final bool previewLoading;
  final bool previewPlaying;
  final VoidCallback onPreview;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final candidate = Map<String, dynamic>.from(result['candidate'] as Map);
    final evidence = Map<String, dynamic>.from(result['evidence'] as Map);
    final isDirectUrl = result['isDirectUrl'] == true;
    final disqualified = evidence['disqualified'] == true;
    final reasons = evidence['reasons'] is List
        ? (evidence['reasons'] as List)
              .map((reason) => reason.toString())
              .take(3)
              .join(' · ')
        : '';
    final score = ((result['score'] as num?)?.toDouble() ?? 0) * 100;
    final source = switch (candidate['sourceType']) {
      'youtube_music_song' => 'YouTube Music',
      'youtube_exact_video' => 'Exact YouTube video',
      _ => 'YouTube',
    };
    final artist =
        candidate['artist']?.toString() ??
        candidate['videoAuthor']?.toString() ??
        'Unknown artist';
    final album = candidate['album']?.toString() ?? '';
    final duration = _formatManualDuration(candidate['duration']);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PersonalizedSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManualArtwork(candidate: candidate),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate['title']?.toString() ?? 'Unknown result',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.isEmpty ? artist : '$artist · $album',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              isDirectUrl
                                  ? 'Exact link'
                                  : disqualified
                                  ? 'Manual choice'
                                  : '${score.round()}% match',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            duration.isEmpty ? source : '$source · $duration',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reasons,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (disqualified && !isDirectUrl) ...[
            const SizedBox(height: 8),
            PersonalizedStatusBanner(
              icon: Icons.info_outline_rounded,
              message:
                  'The automatic matcher would skip this result, but manual search leaves the decision to you.',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled && !previewLoading ? onPreview : null,
                  icon: previewLoading
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          previewPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 19,
                        ),
                  label: Text(previewPlaying ? 'Pause' : 'Preview'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: enabled ? onUse : null,
                  icon: const Icon(Icons.check_rounded, size: 19),
                  label: Text(isDirectUrl ? 'Use this video' : 'Use match'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualArtwork extends StatelessWidget {
  const _ManualArtwork({required this.candidate});

  final Map<String, dynamic> candidate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = _manualArtworkUrl(candidate);
    final fallback = ColoredBox(
      color: colors.primaryContainer,
      child: Icon(
        Icons.music_note_rounded,
        color: colors.onPrimaryContainer,
        size: 29,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: 76,
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

String _manualArtworkUrl(Map<String, dynamic> candidate) {
  for (final key in const ['highResImage', 'image', 'lowResImage']) {
    final value = candidate[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _formatManualDuration(dynamic rawSeconds) {
  final seconds = rawSeconds is num
      ? rawSeconds.round()
      : int.tryParse(rawSeconds?.toString() ?? '');
  if (seconds == null || seconds < 0) return '';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
