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
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/review_sprint_prefetch_cache.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';
import 'package:musify/widgets/personalized_ui.dart';
import 'package:musify/widgets/review_swipe_deck.dart';

class SpotifyReviewSprintPage extends StatefulWidget {
  const SpotifyReviewSprintPage({
    super.key,
    this.dataSource,
    this.audioPlayer,
    this.streamResolver,
    this.prefetchCache,
  });

  final SpotifyReviewSprintDataSource? dataSource;
  final ReviewSprintAudioPlayer? audioPlayer;
  final ReviewSprintStreamResolver? streamResolver;
  final ReviewSprintPrefetchCache? prefetchCache;

  @override
  State<SpotifyReviewSprintPage> createState() =>
      _SpotifyReviewSprintPageState();
}

class _SpotifyReviewSprintPageState extends State<SpotifyReviewSprintPage> {
  static const Duration _previewLength = Duration(seconds: 12);
  static const int _clusterAuditThreshold = 5;

  late final SpotifyReviewSprintDataSource _service;
  late final ReviewSprintAudioPlayer _player;
  late final ReviewSprintStreamResolver _streamResolver;
  late final ReviewSprintPrefetchCache _prefetchCache;
  late final bool _ownsPlayer;

  final ReviewSwipeDeckController _deckController = ReviewSwipeDeckController();
  final Map<String, int> _clusterAccepts = <String, int>{};
  final Map<String, int> _clusterRejects = <String, int>{};

  StreamSubscription<ReviewSprintAudioState>? _playerSubscription;
  Timer? _previewTimer;
  Future<void> _audioTail = Future<void>.value();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int _selectedAlternativeIndex = 0;
  int _playbackGeneration = 0;
  int _sessionResolved = 0;
  int _initialQueueSize = 0;
  bool _loading = true;
  bool _saving = false;
  bool _autoPreview = true;
  bool _previewPlaying = false;
  String? _previewLoadingId;
  String? _previewingId;
  String? _error;

  Map<String, dynamic>? get _current => _items.isEmpty ? null : _items.first;

  @override
  void initState() {
    super.initState();
    _service = widget.dataSource ?? const SpotifyReviewWorkflowService();
    _ownsPlayer = widget.audioPlayer == null;
    _player = widget.audioPlayer ?? JustAudioReviewSprintPlayer();
    _streamResolver =
        widget.streamResolver ?? (songId) => fetchSongStreamUrl(songId, false);
    _prefetchCache = widget.prefetchCache ?? ReviewSprintPrefetchCache();
    _playerSubscription = _player.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _previewPlaying = state.playing && !state.completed;
        if (state.completed) {
          _previewingId = null;
          _previewLoadingId = null;
        }
      });
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _playbackGeneration++;
    _previewTimer?.cancel();
    unawaited(_playerSubscription?.cancel());
    if (_ownsPlayer) unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final items = await _service.loadUnresolvedItems();
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(items);
        _selectedAlternativeIndex = 0;
        _initialQueueSize = _initialQueueSize == 0
            ? items.length
            : _initialQueueSize;
        _loading = false;
        _saving = false;
        _error = null;
      });
      await _prepareCurrent();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _prepareCurrent() async {
    final generation = ++_playbackGeneration;
    await _stopPreview();
    if (!mounted || generation != _playbackGeneration || _current == null) {
      return;
    }
    unawaited(_prefetchUpcoming());
    unawaited(_precacheUpcomingArtwork());
    if (_autoPreview && _alternatives(_current!).isNotEmpty) {
      await _startSelectedPreview(generation: generation);
    }
  }

  Future<void> _prefetchUpcoming() async {
    final songIds = <String>[];
    for (final item in _items.take(6)) {
      final alternatives = _alternatives(item);
      if (alternatives.isEmpty) continue;
      final candidate = alternatives.first['candidate'];
      if (candidate is! Map) continue;
      final songId = candidate['ytid']?.toString() ?? '';
      if (songId.isNotEmpty) songIds.add(songId);
    }
    await _prefetchCache.prefetch(songIds, _streamResolver);
  }

  Future<void> _precacheUpcomingArtwork() async {
    final urls = <String>{};
    for (final item in _items.take(4)) {
      final alternatives = _alternatives(item);
      if (alternatives.isEmpty) continue;
      final candidate = alternatives.first['candidate'];
      if (candidate is Map) {
        final url = _artworkUrl(candidate);
        if (url.isNotEmpty) urls.add(url);
      }
    }
    await Future.wait(
      urls.map((url) async {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (_) {
          // The card has its own artwork fallback and can retry on screen.
        }
      }),
    );
  }

  Future<void> _toggleSelectedPreview() async {
    final item = _current;
    if (item == null) return;
    final alternatives = _alternatives(item);
    if (alternatives.isEmpty) return;
    final selected =
        alternatives[_selectedAlternativeIndex.clamp(
          0,
          alternatives.length - 1,
        )];
    final candidate = selected['candidate'];
    if (candidate is! Map) return;
    final songId = candidate['ytid']?.toString() ?? '';
    if (songId.isEmpty || _previewLoadingId == songId) return;

    if (_previewingId == songId) {
      if (_previewPlaying) {
        _previewTimer?.cancel();
        await _runAudio(_player.pause);
      } else {
        await _runAudio(() async {
          _beginPlayback(
            generation: _playbackGeneration,
            itemKey: _itemKey(item),
            songId: songId,
          );
        });
        _armPreviewTimer();
      }
      return;
    }

    final generation = ++_playbackGeneration;
    await _startSelectedPreview(generation: generation);
  }

  Future<void> _startSelectedPreview({required int generation}) async {
    final item = _current;
    if (item == null || generation != _playbackGeneration) return;
    final alternatives = _alternatives(item);
    if (alternatives.isEmpty) return;
    final selectedIndex = _selectedAlternativeIndex.clamp(
      0,
      alternatives.length - 1,
    );
    final selected = alternatives[selectedIndex];
    final candidate = selected['candidate'];
    if (candidate is! Map) return;
    final songId = candidate['ytid']?.toString() ?? '';
    if (songId.isEmpty) return;
    final itemKey = _itemKey(item);

    if (mounted) {
      setState(() {
        _previewLoadingId = songId;
        _previewingId = null;
        _previewPlaying = false;
        _error = null;
      });
    }

    try {
      final url = await _prefetchCache.resolve(songId, _streamResolver);
      if (url == null || url.isEmpty) {
        throw StateError('No playable stream was found for this suggestion.');
      }
      if (!_isCurrentPreview(generation, itemKey, songId)) return;

      await _runAudio(() async {
        if (!_isCurrentPreview(generation, itemKey, songId)) return;
        await _player.stop();
        if (!_isCurrentPreview(generation, itemKey, songId)) return;
        await _player.setUrl(url);
        if (!_isCurrentPreview(generation, itemKey, songId)) return;
        final durationSeconds = _asInt(candidate['duration']);
        final start = durationSeconds != null && durationSeconds > 75
            ? const Duration(seconds: 20)
            : Duration.zero;
        if (start > Duration.zero) await _player.seek(start);
        if (!_isCurrentPreview(generation, itemKey, songId)) return;
        if (mounted) {
          setState(() {
            _previewingId = songId;
            _previewLoadingId = null;
          });
        }
        _beginPlayback(
          generation: generation,
          itemKey: itemKey,
          songId: songId,
        );
      });
      if (_isCurrentPreview(generation, itemKey, songId)) {
        _armPreviewTimer();
      }
    } catch (error) {
      if (!_isCurrentPreview(generation, itemKey, songId)) return;
      await _stopPreview();
      if (!mounted) return;
      setState(() => _error = 'Preview failed: $error');
    }
  }

  bool _isCurrentPreview(int generation, String itemKey, String songId) {
    if (!mounted || generation != _playbackGeneration) return false;
    final item = _current;
    if (item == null || _itemKey(item) != itemKey) return false;
    final alternatives = _alternatives(item);
    if (alternatives.isEmpty) return false;
    final selected =
        alternatives[_selectedAlternativeIndex.clamp(
          0,
          alternatives.length - 1,
        )];
    final candidate = selected['candidate'];
    return candidate is Map && candidate['ytid']?.toString() == songId;
  }

  void _beginPlayback({
    required int generation,
    required String itemKey,
    required String songId,
  }) {
    try {
      unawaited(
        _player.play().catchError((Object error, StackTrace _) {
          if (!_isCurrentPreview(generation, itemKey, songId)) return;
          setState(() {
            _previewPlaying = false;
            _error = 'Preview failed: $error';
          });
        }),
      );
    } catch (error) {
      if (!_isCurrentPreview(generation, itemKey, songId)) return;
      setState(() {
        _previewPlaying = false;
        _error = 'Preview failed: $error';
      });
    }
  }

  Future<void> _runAudio(Future<void> Function() operation) {
    final next = _audioTail.then(
      (_) => operation(),
      onError: (_) => operation(),
    );
    _audioTail = next;
    return next;
  }

  void _armPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewLength, () {
      _playbackGeneration++;
      unawaited(_stopPreview());
    });
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    try {
      await _runAudio(_player.stop);
    } catch (_) {
      // A failed or already-disposed player needs no extra recovery.
    }
    if (!mounted) return;
    setState(() {
      _previewPlaying = false;
      _previewLoadingId = null;
      _previewingId = null;
    });
  }

  Future<bool> _handleDeckAction(ReviewSwipeAction action) {
    return switch (action) {
      ReviewSwipeAction.accept => _persistDecision(accept: true),
      ReviewSwipeAction.reject => _persistDecision(accept: false),
      ReviewSwipeAction.postpone => _postpone(),
    };
  }

  Future<bool> _persistDecision({required bool accept}) async {
    final item = _current;
    if (item == null || _saving) return false;
    final alternatives = _alternatives(item);
    if (accept && alternatives.isEmpty) return false;
    final selected = accept
        ? alternatives[_selectedAlternativeIndex.clamp(
            0,
            alternatives.length - 1,
          )]
        : null;
    final cluster = SpotifyReviewWorkflowService.clusterKey(item);
    final sourceIsrc = _normalizeIsrc(item['sourceIsrc']?.toString() ?? '');
    _playbackGeneration++;
    await _stopPreview();
    if (!mounted) return false;
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
      if (!mounted) return false;
      if (accept) {
        _clusterAccepts[cluster] = (_clusterAccepts[cluster] ?? 0) + 1;
      } else {
        _clusterRejects[cluster] = (_clusterRejects[cluster] ?? 0) + 1;
      }
      final removed = <Map<String, dynamic>>[];
      for (final queued in _items) {
        final sameItem = _itemKey(queued) == _itemKey(item);
        final duplicate =
            result.duplicatesApplied > 0 &&
            sourceIsrc.isNotEmpty &&
            _normalizeIsrc(queued['sourceIsrc']?.toString() ?? '') ==
                sourceIsrc;
        if (sameItem || duplicate) removed.add(queued);
      }
      setState(() {
        _items.removeWhere(removed.contains);
        _selectedAlternativeIndex = 0;
        _sessionResolved += removed.isEmpty ? 1 : removed.length;
        _saving = false;
      });
      if (result.duplicatesApplied > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Also resolved ${result.duplicatesApplied} exact-ISRC duplicate${result.duplicatesApplied == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
      unawaited(_prepareCurrent());
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _error = 'Decision was not saved. Try again.\n$error';
      });
      unawaited(_prepareCurrent());
      return false;
    }
  }

  Future<bool> _postpone() async {
    if (_items.length <= 1 || _saving) return false;
    _playbackGeneration++;
    await _stopPreview();
    if (!mounted) return false;
    setState(() {
      final first = _items.removeAt(0);
      _items.add(first);
      _selectedAlternativeIndex = 0;
      _error = null;
    });
    unawaited(_prepareCurrent());
    return true;
  }

  Future<void> _selectAlternative(int index) async {
    if (_saving || _current == null) return;
    final alternatives = _alternatives(_current!);
    if (index < 0 || index >= alternatives.length) return;
    setState(() => _selectedAlternativeIndex = index);
    await _prepareCurrent();
  }

  Future<void> _manualSearch() async {
    final item = _current;
    if (item == null || _saving) return;
    _playbackGeneration++;
    await _stopPreview();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      personalizedPageRoute<bool>(
        builder: (_) => SpotifyManualMatchPage(item: item),
      ),
    );
    if (saved == true) {
      _sessionResolved++;
      await _load(showLoading: false);
    } else {
      await _prepareCurrent();
    }
  }

  Future<void> _excludeCurrent() async {
    final item = _current;
    if (item == null || _saving) return;
    final title = item['sourceTitle']?.toString().trim();
    final confirmed = await showPersonalizedDestructiveConfirmation(
      context: context,
      title: 'Exclude “${title?.isNotEmpty == true ? title : 'this track'}”?',
      message:
          'This removes the track from review, rescue, and every destination for this import. It will not remove anything already in Liked Songs.',
      confirmLabel: 'Exclude',
    );
    if (!confirmed || !mounted) return;

    _playbackGeneration++;
    await _stopPreview();
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.excludeItem(item: item);
      if (!mounted) return;
      setState(() {
        _items.removeWhere(
          (candidate) => _itemKey(candidate) == _itemKey(item),
        );
        _selectedAlternativeIndex = 0;
        _sessionResolved++;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track excluded from this import workflow.'),
        ),
      );
      unawaited(_prepareCurrent());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Track was not excluded. $error';
      });
      unawaited(_prepareCurrent());
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
          'You accepted at least five examples from this exact evidence cluster without rejecting one. Only tracks that still pass the strict identity and version checks are included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approve verified group'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    _playbackGeneration++;
    await _stopPreview();
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final importSessionId =
          item[SpotifyReviewWorkflowService.importSessionItemKey]
              ?.toString() ??
          '';
      final applied = await _service.bulkApproveCluster(
        key: key,
        importSessionId: importSessionId,
      );
      _sessionResolved += applied;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved $applied verified matches.')),
      );
      await _load(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
      unawaited(_prepareCurrent());
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
    final alternatives = item == null
        ? <Map<String, dynamic>>[]
        : _alternatives(item);
    final selected = alternatives.isEmpty
        ? null
        : alternatives[_selectedAlternativeIndex.clamp(
            0,
            alternatives.length - 1,
          )];
    final nextItem = _items.length > 1 ? _items[1] : null;
    final nextAlternatives = nextItem == null
        ? <Map<String, dynamic>>[]
        : _alternatives(nextItem);
    final progressDenominator = _initialQueueSize == 0 ? 1 : _initialQueueSize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick review'),
        actions: [
          if (!_loading && item != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        '${_items.length} left',
                        key: ValueKey(_items.length),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
          ? _FinishedState(sessionResolved: _sessionResolved)
          : SafeArea(
              child: Column(
                children: [
                  _SprintStatusBar(
                    progress: (_sessionResolved / progressDenominator).clamp(
                      0,
                      1,
                    ),
                    resolved: _sessionResolved,
                    autoPreview: _autoPreview,
                    saving: _saving,
                    onAutoPreviewChanged: (value) async {
                      setState(() => _autoPreview = value);
                      if (value) {
                        await _prepareCurrent();
                      } else {
                        _playbackGeneration++;
                        await _stopPreview();
                      }
                    },
                  ),
                  if (_error != null)
                    _InlineError(
                      message: _error!,
                      onDismissed: () => setState(() => _error = null),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0.04, 0.025),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        child: ReviewSwipeDeck(
                          key: ValueKey(_itemKey(item)),
                          controller: _deckController,
                          enabled: !_saving,
                          canAccept: alternatives.isNotEmpty,
                          currentCard: _ReviewSongCard(
                            item: item,
                            alternative: selected,
                            candidateIndex: _selectedAlternativeIndex,
                            candidateCount: alternatives.length,
                            previewLoadingId: _previewLoadingId,
                            previewingId: _previewingId,
                            previewPlaying: _previewPlaying,
                            onPreview: _toggleSelectedPreview,
                            onPreviousCandidate: _selectedAlternativeIndex > 0
                                ? () => _selectAlternative(
                                    _selectedAlternativeIndex - 1,
                                  )
                                : null,
                            onNextCandidate:
                                _selectedAlternativeIndex + 1 <
                                    alternatives.length
                                ? () => _selectAlternative(
                                    _selectedAlternativeIndex + 1,
                                  )
                                : null,
                          ),
                          nextCard: nextItem == null
                              ? null
                              : _ReviewSongCard(
                                  item: nextItem,
                                  alternative: nextAlternatives.isEmpty
                                      ? null
                                      : nextAlternatives.first,
                                  candidateIndex: 0,
                                  candidateCount: nextAlternatives.length,
                                  previewLoadingId: null,
                                  previewingId: null,
                                  previewPlaying: false,
                                  behind: true,
                                ),
                          onAction: _handleDeckAction,
                        ),
                      ),
                    ),
                  ),
                  if (_saving) const LinearProgressIndicator(minHeight: 2),
                  _SprintActions(
                    canAccept: alternatives.isNotEmpty && !_saving,
                    canPostpone: _items.length > 1 && !_saving,
                    enabled: !_saving,
                    onReject: () => unawaited(
                      _deckController.perform(ReviewSwipeAction.reject),
                    ),
                    onPostpone: () => unawaited(
                      _deckController.perform(ReviewSwipeAction.postpone),
                    ),
                    onAccept: () => unawaited(
                      _deckController.perform(ReviewSwipeAction.accept),
                    ),
                    onManualSearch: _manualSearch,
                    onExclude: _excludeCurrent,
                    bulkApprovalAvailable: _clusterBulkApprovalAvailable(item),
                    onBulkApprove: _bulkApproveCurrentCluster,
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

  static String _itemKey(Map<String, dynamic> item) {
    return item['sourceRow']?.toString() ??
        '${item['sourceArtist']}:${item['sourceTitle']}';
  }

  static String _normalizeIsrc(String value) {
    return value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  }
}

class _SprintStatusBar extends StatelessWidget {
  const _SprintStatusBar({
    required this.progress,
    required this.resolved,
    required this.autoPreview,
    required this.saving,
    required this.onAutoPreviewChanged,
  });

  final double progress;
  final int resolved;
  final bool autoPreview;
  final bool saving;
  final ValueChanged<bool> onAutoPreviewChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$resolved reviewed',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            autoPreview ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            size: 19,
            color: colors.onSurfaceVariant,
          ),
          Semantics(
            label: 'Auto-play previews',
            child: Switch.adaptive(
              value: autoPreview,
              onChanged: saving ? null : onAutoPreviewChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: PersonalizedStatusBanner(
        tone: PersonalizedStatusTone.error,
        message: message,
        trailing: IconButton(
          onPressed: onDismissed,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Dismiss',
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ReviewSongCard extends StatelessWidget {
  const _ReviewSongCard({
    required this.item,
    required this.alternative,
    required this.candidateIndex,
    required this.candidateCount,
    required this.previewLoadingId,
    required this.previewingId,
    required this.previewPlaying,
    this.onPreview,
    this.onPreviousCandidate,
    this.onNextCandidate,
    this.behind = false,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? alternative;
  final int candidateIndex;
  final int candidateCount;
  final String? previewLoadingId;
  final String? previewingId;
  final bool previewPlaying;
  final VoidCallback? onPreview;
  final VoidCallback? onPreviousCandidate;
  final VoidCallback? onNextCandidate;
  final bool behind;

  @override
  Widget build(BuildContext context) {
    final candidate = alternative?['candidate'] is Map
        ? Map<String, dynamic>.from(alternative!['candidate'] as Map)
        : <String, dynamic>{};
    final evidence = alternative?['evidence'] is Map
        ? Map<String, dynamic>.from(alternative!['evidence'] as Map)
        : <String, dynamic>{};
    final songId = candidate['ytid']?.toString() ?? '';
    final imageUrl = _artworkUrl(candidate);
    final sourceTitle =
        item['sourceTitle']?.toString().trim() ?? 'Unknown track';
    final sourceArtist =
        item['sourceArtist']?.toString().trim() ?? 'Unknown artist';
    final sourceAlbum = item['sourceAlbum']?.toString().trim() ?? '';
    final candidateTitle = candidate['title']?.toString().trim() ?? '';
    final candidateArtist =
        candidate['artist']?.toString().trim().isNotEmpty == true
        ? candidate['artist'].toString().trim()
        : candidate['videoAuthor']?.toString().trim() ?? '';
    final candidateAlbum = candidate['album']?.toString().trim() ?? '';
    final score = _asDouble(alternative?['score']) ?? 0;
    final loading = previewLoadingId == songId && songId.isNotEmpty;
    final playing = previewingId == songId && previewPlaying;
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.48),
        ),
        boxShadow: behind
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 510;
          return Stack(
            fit: StackFit.expand,
            children: [
              _Artwork(imageUrl: imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x18000000),
                      Color(0xB8000000),
                      Color(0xF0000000),
                    ],
                    stops: [0, 0.35, 0.68, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 19,
                  compact ? 15 : 18,
                  compact ? 16 : 19,
                  compact ? 14 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardLabel(
                      icon: Icons.library_music_outlined,
                      label: 'Imported track',
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Text(
                      sourceTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.04,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      sourceAlbum.isEmpty
                          ? sourceArtist
                          : '$sourceArtist • $sourceAlbum',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    _CandidatePanel(
                      item: item,
                      candidate: candidate,
                      evidence: evidence,
                      title: candidateTitle,
                      artist: candidateArtist,
                      album: candidateAlbum,
                      score: score,
                      loading: loading,
                      playing: playing,
                      candidateIndex: candidateIndex,
                      candidateCount: candidateCount,
                      compact: compact,
                      behind: behind,
                      onPreview: onPreview,
                      onPreviousCandidate: onPreviousCandidate,
                      onNextCandidate: onNextCandidate,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    required this.item,
    required this.candidate,
    required this.evidence,
    required this.title,
    required this.artist,
    required this.album,
    required this.score,
    required this.loading,
    required this.playing,
    required this.candidateIndex,
    required this.candidateCount,
    required this.compact,
    required this.behind,
    required this.onPreview,
    required this.onPreviousCandidate,
    required this.onNextCandidate,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic> candidate;
  final Map<String, dynamic> evidence;
  final String title;
  final String artist;
  final String album;
  final double score;
  final bool loading;
  final bool playing;
  final int candidateIndex;
  final int candidateCount;
  final bool compact;
  final bool behind;
  final VoidCallback? onPreview;
  final VoidCallback? onPreviousCandidate;
  final VoidCallback? onNextCandidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = _reasonText(evidence);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 16,
          compact ? 12 : 14,
          compact ? 12 : 14,
          compact ? 10 : 12,
        ),
        child: candidate.isEmpty
            ? _NoSuggestion(item: item)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SUGGESTED MATCH',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            '${(score * 100).round()}% match',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 7 : 9),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.06,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    album.isEmpty ? artist : '$artist • $album',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                  if (reason.isNotEmpty && !compact) ...[
                    const SizedBox(height: 7),
                    Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                  if (!behind) ...[
                    SizedBox(height: compact ? 6 : 9),
                    Row(
                      children: [
                        if (candidateCount > 1) ...[
                          IconButton(
                            key: const ValueKey('review-previous-candidate'),
                            onPressed: onPreviousCandidate,
                            tooltip: 'Previous suggestion',
                            visualDensity: VisualDensity.compact,
                            color: Colors.white,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text(
                            '${candidateIndex + 1} of $candidateCount',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('review-next-candidate'),
                            onPressed: onNextCandidate,
                            tooltip: 'Next suggestion',
                            visualDensity: VisualDensity.compact,
                            color: Colors.white,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ] else
                          Text(
                            'Best available source',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                        const Spacer(),
                        IconButton.filled(
                          key: const ValueKey('review-preview-button'),
                          onPressed: loading ? null : onPreview,
                          tooltip: playing ? 'Pause preview' : 'Play preview',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 86,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
    if (imageUrl.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSuggestion extends StatelessWidget {
  const _NoSuggestion({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final reason =
        item['unmatchedReason']?.toString() ??
        item['error']?.toString() ??
        'No saved suggestion passed the identity and version checks.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const SizedBox.square(
            dimension: 44,
            child: Icon(
              Icons.search_off_rounded,
              size: 23,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No confident suggestion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SprintActions extends StatelessWidget {
  const _SprintActions({
    required this.canAccept,
    required this.canPostpone,
    required this.enabled,
    required this.onReject,
    required this.onPostpone,
    required this.onAccept,
    required this.onManualSearch,
    required this.onExclude,
    required this.bulkApprovalAvailable,
    required this.onBulkApprove,
  });

  final bool canAccept;
  final bool canPostpone;
  final bool enabled;
  final VoidCallback onReject;
  final VoidCallback onPostpone;
  final VoidCallback onAccept;
  final VoidCallback onManualSearch;
  final VoidCallback onExclude;
  final bool bulkApprovalAvailable;
  final VoidCallback onBulkApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.42)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('review-reject-button'),
                    onPressed: enabled ? onReject : null,
                    icon: const Icon(Icons.close_rounded, size: 19),
                    label: const Text('No match'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('review-postpone-button'),
                  onPressed: canPostpone ? onPostpone : null,
                  tooltip: 'Review later',
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.schedule_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('review-accept-button'),
                    onPressed: canAccept ? onAccept : null,
                    icon: const Icon(Icons.check_rounded, size: 19),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  key: const ValueKey('review-manual-search-button'),
                  onPressed: enabled ? onManualSearch : null,
                  icon: const Icon(Icons.manage_search_rounded, size: 19),
                  label: const Text('Search manually'),
                ),
                if (bulkApprovalAvailable)
                  TextButton.icon(
                    onPressed: enabled ? onBulkApprove : null,
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Approve similar'),
                  ),
              ],
            ),
            SizedBox(
              height: 34,
              child: TextButton.icon(
                key: const ValueKey('review-exclude-button'),
                onPressed: enabled ? onExclude : null,
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Exclude permanently'),
              ),
            ),
            Text(
              'Swipe left for no match · right to accept · up for later',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
        child: PersonalizedEmptyState(
          icon: Icons.library_add_check_rounded,
          title: 'Review queue cleared',
          description:
              'You resolved $sessionResolved track${sessionResolved == 1 ? '' : 's'} in this session.',
          action: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Return to matcher'),
          ),
        ),
      ),
    );
  }
}

String _artworkUrl(Map<dynamic, dynamic> candidate) {
  for (final key in const ['highResImage', 'image', 'lowResImage']) {
    final value = candidate[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _reasonText(Map<String, dynamic> evidence) {
  final raw = evidence['reasons'];
  if (raw is! List) return '';
  return raw.map((reason) => reason.toString()).take(3).join(' • ');
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
