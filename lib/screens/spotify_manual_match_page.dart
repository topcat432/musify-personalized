/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/spotify_match_scoring.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

class SpotifyManualMatchPage extends StatefulWidget {
  const SpotifyManualMatchPage({required this.item, super.key});

  final Map<String, dynamic> item;

  @override
  State<SpotifyManualMatchPage> createState() =>
      _SpotifyManualMatchPageState();
}

class _SpotifyManualMatchPageState extends State<SpotifyManualMatchPage> {
  static final YoutubeMusicExplode _youtubeMusic = YoutubeMusicExplode();
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

      final input = SpotifyMatchInput(
        title: widget.item['sourceTitle']?.toString() ?? '',
        artist: widget.item['sourceArtist']?.toString() ?? '',
        album: widget.item['sourceAlbum']?.toString() ?? '',
        isrc: widget.item['sourceIsrc']?.toString() ?? '',
        durationMs: _asInt(widget.item['sourceDurationMs']),
      );

      final ranked = <Map<String, dynamic>>[];
      for (final candidate in candidates) {
        final evidence = SpotifyMatchScorer.score(input, candidate);
        if (evidence.disqualified) continue;
        ranked.add({
          'candidate': candidate,
          'score': evidence.score,
          'evidence': evidence.toJson(),
        });
      }
      ranked.sort(
        (left, right) => (right['score'] as double).compareTo(
          left['score'] as double,
        ),
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
        ..['reviewDecision'] = 'manual_search'
        ..['manualSearchQuery'] = _queryController.text.trim()
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
    return Scaffold(
      appBar: AppBar(title: const Text('Find a match manually')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['sourceTitle']?.toString() ?? 'Unknown track',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(widget.item['sourceArtist']?.toString() ?? ''),
                  if ((widget.item['sourceAlbum']?.toString() ?? '').isNotEmpty)
                    Text(
                      widget.item['sourceAlbum'].toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Search title, artist, album, or version',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (_results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No safe song results found. Change the wording, add an album or version name, and search again.',
                ),
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Preview plays up to 30 seconds and stops automatically. Listen before saving when titles or versions are ambiguous.',
              ),
            ),
            for (final result in _results)
              _ManualResultTile(
                result: result,
                enabled: !_saving,
                previewLoading: _previewLoadingId ==
                    (result['candidate'] as Map)['ytid']?.toString(),
                previewPlaying: _previewPlaying &&
                    _previewingId ==
                        (result['candidate'] as Map)['ytid']?.toString(),
                onPreview: () => _togglePreview(result),
                onUse: () => _save(result),
              ),
          ],
        ],
      ),
    );
  }

  static bool _isMatched(Map<String, dynamic> item) {
    return item['status'] == 'matched' || item['status'] == 'manually_matched';
  }

  static bool _isUnmatched(Map<String, dynamic> item) {
    return item['status'] == 'unmatched' || item['status'] == 'manual_unmatched';
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
    final reasons = evidence['reasons'] is List
        ? (evidence['reasons'] as List)
            .map((reason) => reason.toString())
            .take(3)
            .join(' • ')
        : '';
    final score = ((result['score'] as num?)?.toDouble() ?? 0) * 100;
    final source = candidate['sourceType'] == 'youtube_music_song'
        ? 'YouTube Music'
        : 'YouTube';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate['title']?.toString() ?? 'Unknown result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(
              candidate['artist']?.toString() ??
                  candidate['videoAuthor']?.toString() ??
                  'Unknown artist',
            ),
            const SizedBox(height: 4),
            Text(
              '${score.round()}% • $source${reasons.isEmpty ? '' : ' • $reasons'}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled && !previewLoading ? onPreview : null,
                    icon: previewLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(previewPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(previewPlaying ? 'Pause preview' : 'Preview'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: enabled ? onUse : null,
                    child: const Text('Use this match'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
