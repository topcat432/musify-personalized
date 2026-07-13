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
import 'package:just_audio/just_audio.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

class SpotifyReviewSprintPage extends StatefulWidget {
  const SpotifyReviewSprintPage({super.key});

  @override
  State<SpotifyReviewSprintPage> createState() =>
      _SpotifyReviewSprintPageState();
}

class _SpotifyReviewSprintPageState extends State<SpotifyReviewSprintPage> {
  static const Duration _previewLength = Duration(seconds: 12);
  static const int _clusterAuditThreshold = 5;

  final SpotifyReviewWorkflowService _service =
      const SpotifyReviewWorkflowService();
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _prefetchedUrls = {};
  final Map<String, int> _clusterAccepts = {};
  final Map<String, int> _clusterRejects = {};

  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _previewTimer;
  List<Map<String, dynamic>> _items = [];
  int _selectedAlternativeIndex = 0;
  bool _loading = true;
  bool _saving = false;
  bool _autoPreview = true;
  bool _previewPlaying = false;
  String? _previewLoadingId;
  String? _previewingId;
  String? _error;
  int _sessionResolved = 0;

  Map<String, dynamic>? get _current => _items.isEmpty ? null : _items.first;

  @override
  void initState() {
    super.initState();
    _playerSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final complete = state.processingState == ProcessingState.completed;
      setState(() {
        _previewPlaying = state.playing && !complete;
        if (complete) {
          _previewingId = null;
          _previewLoadingId = null;
        }
      });
    });
    _load();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _playerSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _service.loadUnresolvedItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _selectedAlternativeIndex = 0;
        _loading = false;
        _error = null;
      });
      await _prepareCurrent();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _prepareCurrent() async {
    await _stopPreview();
    if (!mounted || _current == null) return;
    unawaited(_prefetchUpcoming());
    if (_autoPreview && _alternatives(_current!).isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) await _playSelectedPreview();
    }
  }

  Future<void> _prefetchUpcoming() async {
    final upcoming = _items.take(4);
    for (final item in upcoming) {
      final alternatives = _alternatives(item);
      if (alternatives.isEmpty) continue;
      final candidate = alternatives.first['candidate'];
      if (candidate is! Map) continue;
      final songId = candidate['ytid']?.toString() ?? '';
      if (songId.isEmpty || _prefetchedUrls.containsKey(songId)) continue;
      try {
        final url = await fetchSongStreamUrl(songId, false);
        if (url != null && url.isNotEmpty) {
          _prefetchedUrls[songId] = url;
          while (_prefetchedUrls.length > 8) {
            _prefetchedUrls.remove(_prefetchedUrls.keys.first);
          }
        }
      } catch (_) {
        // A failed prefetch is retried normally when the track becomes current.
      }
    }
  }

  Future<void> _playSelectedPreview() async {
    final item = _current;
    if (item == null || _saving) return;
    final alternatives = _alternatives(item);
    if (alternatives.isEmpty) return;
    final index = _selectedAlternativeIndex.clamp(0, alternatives.length - 1);
    final candidate = alternatives[index]['candidate'];
    if (candidate is! Map) return;
    final songId = candidate['ytid']?.toString() ?? '';
    if (songId.isEmpty || _previewLoadingId == songId) return;

    if (_previewingId == songId) {
      if (_previewPlaying) {
        _previewTimer?.cancel();
        await _player.pause();
      } else {
        await _player.play();
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
      final url = _prefetchedUrls[songId] ??
          await fetchSongStreamUrl(songId, false);
      if (url == null || url.isEmpty) {
        throw StateError('No playable stream was found for this candidate.');
      }
      _prefetchedUrls[songId] = url;
      await _player.setUrl(url);
      final durationSeconds = _asInt(candidate['duration']);
      final start = durationSeconds != null && durationSeconds > 75
          ? const Duration(seconds: 20)
          : Duration.zero;
      if (start > Duration.zero) await _player.seek(start);
      if (!mounted) return;
      setState(() {
        _previewingId = songId;
        _previewLoadingId = null;
      });
      await _player.play();
      _armPreviewTimer();
    } catch (error) {
      await _stopPreview();
      if (!mounted) return;
      setState(() => _error = 'Preview failed: $error');
    }
  }

  void _armPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewLength, () => unawaited(_stopPreview()));
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    try {
      await _player.stop();
    } catch (_) {
      // Stopping an already-disposed or failed player needs no extra recovery.
    }
    if (!mounted) return;
    setState(() {
      _previewPlaying = false;
      _previewLoadingId = null;
      _previewingId = null;
    });
  }

  Future<void> _resolve({required bool accept}) async {
    final item = _current;
    if (item == null || _saving) return;
    final alternatives = _alternatives(item);
    final selected = accept && alternatives.isNotEmpty
        ? alternatives[_selectedAlternativeIndex.clamp(0, alternatives.length - 1)]
        : null;
    final cluster = SpotifyReviewWorkflowService.clusterKey(item);

    await _stopPreview();
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await _service.resolveItem(
        item: item,
        accept: accept,
        selectedAlternative: selected,
      );
      if (accept) {
        _clusterAccepts[cluster] = (_clusterAccepts[cluster] ?? 0) + 1;
      } else {
        _clusterRejects[cluster] = (_clusterRejects[cluster] ?? 0) + 1;
      }
      _sessionResolved++;
      if (!mounted) return;
      if (result.duplicatesApplied > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Applied this source to ${result.duplicatesApplied} exact-ISRC duplicate${result.duplicatesApplied == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _postpone() async {
    if (_items.length <= 1 || _saving) return;
    await _stopPreview();
    if (!mounted) return;
    setState(() {
      final first = _items.removeAt(0);
      _items.add(first);
      _selectedAlternativeIndex = 0;
    });
    await _prepareCurrent();
  }

  Future<void> _manualSearch() async {
    final item = _current;
    if (item == null || _saving) return;
    await _stopPreview();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SpotifyManualMatchPage(item: item),
      ),
    );
    if (saved == true) {
      _sessionResolved++;
      await _load();
    } else {
      await _prepareCurrent();
    }
  }

  Future<void> _bulkApproveCurrentCluster() async {
    final item = _current;
    if (item == null || _saving) return;
    final key = SpotifyReviewWorkflowService.clusterKey(item);
    final count = _items
        .where(
          (candidate) =>
              SpotifyReviewWorkflowService.clusterKey(candidate) == key &&
              SpotifyReviewWorkflowService.isSafeClusterItem(candidate),
        )
        .length;
    if (count == 0) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Approve $count matching-pattern tracks?'),
        content: const Text(
          'You accepted at least five examples from this exact evidence cluster without rejecting one. Only tracks that still meet the strict title, artist, source, album, duration, and version-safety checks will be approved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approve safe cluster'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _saving = true);
    try {
      final applied = await _service.bulkApproveCluster(key);
      _sessionResolved += applied;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved $applied safely matching tracks.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _clusterBulkApprovalAvailable(Map<String, dynamic> item) {
    final key = SpotifyReviewWorkflowService.clusterKey(item);
    return SpotifyReviewWorkflowService.isSafeClusterItem(item) &&
        (_clusterAccepts[key] ?? 0) >= _clusterAuditThreshold &&
        (_clusterRejects[key] ?? 0) == 0;
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final alternatives = item == null ? <Map<String, dynamic>>[] : _alternatives(item);
    final selected = alternatives.isEmpty
        ? null
        : alternatives[_selectedAlternativeIndex.clamp(0, alternatives.length - 1)];
    final candidate = selected?['candidate'] is Map
        ? Map<String, dynamic>.from(selected!['candidate'] as Map)
        : <String, dynamic>{};
    final evidence = selected?['evidence'] is Map
        ? Map<String, dynamic>.from(selected!['evidence'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Review sprint' : 'Review sprint (${_items.length})'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? _FinishedState(sessionResolved: _sessionResolved)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 650 && alternatives.isNotEmpty) {
                  unawaited(_resolve(accept: true));
                } else if (velocity < -650) {
                  unawaited(_resolve(accept: false));
                }
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -650) unawaited(_postpone());
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _sessionResolved == 0
                              ? 0
                              : _sessionResolved /
                                  (_sessionResolved + _items.length),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$_sessionResolved done'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-play top preview'),
                    subtitle: const Text(
                      'Pre-resolves the next few streams and plays a 12-second sample.',
                    ),
                    value: _autoPreview,
                    onChanged: _saving
                        ? null
                        : (value) async {
                            setState(() => _autoPreview = value);
                            if (value) {
                              await _playSelectedPreview();
                            } else {
                              await _stopPreview();
                            }
                          },
                  ),
                  if (_error != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['sourceTitle']?.toString() ?? 'Unknown track',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['sourceArtist']?.toString() ?? 'Unknown artist',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if ((item['sourceAlbum']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(item['sourceAlbum'].toString()),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            SpotifyReviewWorkflowService.clusterLabel(item),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (alternatives.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No safe suggestion is saved for this track. Search manually, postpone it, or mark it unmatched.',
                        ),
                      ),
                    )
                  else ...[
                    if (alternatives.length > 1)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var index = 0; index < alternatives.length; index++)
                            ChoiceChip(
                              label: Text('Candidate ${index + 1}'),
                              selected: index == _selectedAlternativeIndex,
                              onSelected: _saving
                                  ? null
                                  : (_) async {
                                      setState(() => _selectedAlternativeIndex = index);
                                      if (_autoPreview) await _playSelectedPreview();
                                    },
                            ),
                        ],
                      ),
                    if (alternatives.length > 1) const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate['title']?.toString() ?? 'Unknown candidate',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              candidate['artist']?.toString() ??
                                  candidate['videoAuthor']?.toString() ??
                                  'Unknown artist',
                            ),
                            if ((candidate['album']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(candidate['album'].toString()),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${((_asDouble(selected?['score']) ?? 0) * 100).round()}% confidence${_reasonText(evidence).isEmpty ? '' : ' • ${_reasonText(evidence)}'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _saving ||
                                        _previewLoadingId ==
                                            candidate['ytid']?.toString()
                                    ? null
                                    : _playSelectedPreview,
                                icon: _previewLoadingId ==
                                        candidate['ytid']?.toString()
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _previewPlaying &&
                                                _previewingId ==
                                                    candidate['ytid']?.toString()
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                label: Text(
                                  _previewPlaying &&
                                          _previewingId ==
                                              candidate['ytid']?.toString()
                                      ? 'Pause preview'
                                      : 'Play preview',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || alternatives.isEmpty
                          ? null
                          : () => _resolve(accept: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept this match'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _resolve(accept: false),
                      icon: const Icon(Icons.close),
                      label: const Text('None are correct'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _manualSearch,
                      icon: const Icon(Icons.manage_search),
                      label: const Text('Search manually'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _saving ? null : _postpone,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Postpone this track'),
                  ),
                  if (_clusterBulkApprovalAvailable(item)) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evidence cluster audited',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'You accepted five examples from this exact safe pattern without rejecting one.',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving
                                    ? null
                                    : _bulkApproveCurrentCluster,
                                child: const Text(
                                  'Approve remaining safe matches like this',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Quick gestures: swipe right to accept, left for none, or up to postpone. Buttons remain the safer primary controls.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  static List<Map<String, dynamic>> _alternatives(Map<String, dynamic> item) {
    final raw = item['alternatives'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  static String _reasonText(Map<String, dynamic> evidence) {
    final raw = evidence['reasons'];
    if (raw is! List) return '';
    return raw.map((reason) => reason.toString()).take(3).join(' • ');
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
}

class _FinishedState extends StatelessWidget {
  const _FinishedState({required this.sessionResolved});

  final int sessionResolved;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Review queue cleared',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'You resolved $sessionResolved track${sessionResolved == 1 ? '' : 's'} in this sprint.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Return to matcher'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
