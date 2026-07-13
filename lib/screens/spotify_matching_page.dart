/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/screens/spotify_match_review_page.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

class SpotifyMatchingPage extends StatefulWidget {
  const SpotifyMatchingPage({super.key});

  @override
  State<SpotifyMatchingPage> createState() => _SpotifyMatchingPageState();
}

class _SpotifyMatchingPageState extends State<SpotifyMatchingPage> {
  static const int _allRemaining = -1;

  final _service = const SpotifyTrackMatchingService();
  SpotifyMatchingSnapshot? _snapshot;
  bool _loading = true;
  bool _running = false;
  bool _stopRequested = false;
  int _selectedRunSize = SpotifyTrackMatchingService.defaultBatchSize;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
        if (!_allRemainingUnlocked(snapshot) &&
            _selectedRunSize == _allRemaining) {
          _selectedRunSize = SpotifyTrackMatchingService.defaultBatchSize;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _confirmAllRemaining(SpotifyMatchingSnapshot snapshot) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Match all ${snapshot.remainingCount} remaining tracks?'),
        content: const Text(
          'This may take a long time. Keep the app open, preferably on Wi-Fi and charging. Progress is saved every five tracks, and you can pause safely at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Run all remaining'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _runSelectedBatch() async {
    if (_running) return;
    var current = _snapshot;
    if (current == null || current.isComplete) return;

    final runAll = _selectedRunSize == _allRemaining;
    if (runAll) {
      if (!_allRemainingUnlocked(current)) return;
      if (!await _confirmAllRemaining(current)) return;
    }

    setState(() {
      _running = true;
      _stopRequested = false;
      _error = null;
    });

    try {
      if (runAll) {
        while (mounted && !_stopRequested && !current!.isComplete) {
          final before = current.nextTrackIndex;
          current = await _service.matchNextBatch(
            batchSize: SpotifyTrackMatchingService.maximumPilotBatchSize,
            shouldStop: () => _stopRequested,
            onProgress: (progress) {
              if (mounted) setState(() => _snapshot = progress);
            },
          );
          if (!mounted) return;
          setState(() => _snapshot = current);
          if (current.nextTrackIndex <= before) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } else {
        current = await _service.matchNextBatch(
          batchSize: _selectedRunSize,
          shouldStop: () => _stopRequested,
          onProgress: (progress) {
            if (mounted) setState(() => _snapshot = progress);
          },
        );
        if (!mounted) return;
        setState(() => _snapshot = current);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _stopRequested = false;
        });
      }
    }
  }

  Future<void> _openResolutionQueue() async {
    if (_running) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SpotifyMatchReviewPage(),
      ),
    );
    await _load();
  }

  Future<void> _restartMatching() async {
    if (_running) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restart matching?'),
        content: const Text(
          'This clears the current staged matching results and starts again with the newest finder. Your imported CSV remains saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    try {
      final snapshot = await _service.restartMatching();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedRunSize = SpotifyTrackMatchingService.defaultBatchSize;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Match imported tracks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.library_music_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Catalog-first matching',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The finder searches structured YouTube Music song results first, then uses ordinary YouTube only as a fallback. It compares title, artists, album, duration, version, and source reliability.',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Uncertain or missing tracks can now be searched and saved manually. Nothing is added to Favorites until the import is finalized.',
                        ),
                      ],
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
                const SizedBox(height: 12),
                if (snapshot == null || !snapshot.hasImport)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No saved Spotify import was found. Return to the importer and save a CSV first.',
                      ),
                    ),
                  )
                else ...[
                  _ProgressCard(snapshot: snapshot),
                  const SizedBox(height: 12),
                  _RunControlsCard(
                    selectedRunSize: _selectedRunSize,
                    allRemainingValue: _allRemaining,
                    remainingCount: snapshot.remainingCount,
                    allRemainingUnlocked: _allRemainingUnlocked(snapshot),
                    enabled: !_running && !snapshot.isComplete,
                    onSelected: (value) =>
                        setState(() => _selectedRunSize = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: snapshot.isComplete
                          ? null
                          : _running
                          ? () => setState(() => _stopRequested = true)
                          : _runSelectedBatch,
                      icon: Icon(
                        snapshot.isComplete
                            ? Icons.check_circle
                            : _running
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        snapshot.isComplete
                            ? 'Matching complete'
                            : _running
                            ? _stopRequested
                                  ? 'Pausing after this track…'
                                  : 'Pause safely'
                            : _selectedRunSize == _allRemaining
                            ? 'Match all ${snapshot.remainingCount} remaining'
                            : 'Match next $_selectedRunSize tracks',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _unresolvedCount(snapshot) == 0 || _running
                          ? null
                          : _openResolutionQueue,
                      icon: const Icon(Icons.manage_search),
                      label: Text(
                        _unresolvedCount(snapshot) == 0
                            ? 'No unresolved matches waiting'
                            : 'Review or search ${_unresolvedCount(snapshot)} unresolved',
                      ),
                    ),
                  ),
                  if (_running && _unresolvedCount(snapshot) > 0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pause safely before resolving tracks manually. Matching resumes from the saved checkpoint afterward.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_selectedRunSize == _allRemaining && !_running) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'All-remaining runs in safe 50-track sections and preserves a checkpoint every five tracks.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (snapshot.nextTrackIndex > 0 && !_running) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _restartMatching,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restart with the newest matcher'),
                    ),
                  ],
                  if (snapshot.recentResults.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Most recent results',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final result in snapshot.recentResults)
                            _ResultTile(result: result),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  static int _unresolvedCount(SpotifyMatchingSnapshot snapshot) {
    return snapshot.pendingResolutionCount;
  }

  static bool _allRemainingUnlocked(SpotifyMatchingSnapshot snapshot) {
    if (snapshot.nextTrackIndex < 50) return false;
    final usableAttempts = snapshot.nextTrackIndex - snapshot.errorCount;
    if (usableAttempts <= 0) return false;
    final strongOrReview = snapshot.matchedCount + snapshot.reviewCount;
    final usefulRate = strongOrReview / usableAttempts;
    final unmatchedRate = snapshot.unmatchedCount / usableAttempts;
    return usefulRate >= 0.90 && unmatchedRate <= 0.10;
  }
}

class _RunControlsCard extends StatelessWidget {
  const _RunControlsCard({
    required this.selectedRunSize,
    required this.allRemainingValue,
    required this.remainingCount,
    required this.allRemainingUnlocked,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedRunSize;
  final int allRemainingValue;
  final int remainingCount;
  final bool allRemainingUnlocked;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How much should run?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              allRemainingUnlocked
                  ? 'The first sample passed the safety gate, so all-remaining mode is available.'
                  : 'Process at least 50 tracks with a strong real-world match rate to unlock all remaining.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('25 tracks'),
                  selected: selectedRunSize == 25,
                  onSelected: enabled ? (_) => onSelected(25) : null,
                ),
                ChoiceChip(
                  label: const Text('50 tracks'),
                  selected: selectedRunSize == 50,
                  onSelected: enabled ? (_) => onSelected(50) : null,
                ),
                ChoiceChip(
                  label: Text('All remaining ($remainingCount)'),
                  selected: selectedRunSize == allRemainingValue,
                  onSelected: enabled && allRemainingUnlocked
                      ? (_) => onSelected(allRemainingValue)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.snapshot});

  final SpotifyMatchingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${snapshot.nextTrackIndex} of ${snapshot.totalTracks} processed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${(snapshot.progress * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: snapshot.progress),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  icon: Icons.check_circle,
                  label: 'Strong',
                  count: snapshot.matchedCount,
                ),
                _CountChip(
                  icon: Icons.help,
                  label: 'Review',
                  count: snapshot.reviewCount,
                ),
                _CountChip(
                  icon: Icons.search_off,
                  label: 'Unmatched',
                  count: snapshot.unmatchedCount,
                ),
                if (snapshot.errorCount > 0)
                  _CountChip(
                    icon: Icons.error,
                    label: 'Errors',
                    count: snapshot.errorCount,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label $count'),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final status = result['status']?.toString() ?? 'unmatched';
    final score = result['score'] is num
        ? (result['score'] as num).toDouble()
        : 0.0;
    final candidate = result['bestCandidate'] is Map
        ? Map<String, dynamic>.from(result['bestCandidate'] as Map)
        : <String, dynamic>{};

    final (icon, label) = switch (status) {
      'matched' => (Icons.check_circle, 'Strong match'),
      'manually_matched' => (Icons.verified, 'Manually confirmed'),
      'needs_review' => (Icons.help, 'Needs review'),
      'manual_unmatched' => (Icons.block, 'Marked unmatched'),
      'error' => (Icons.error, 'Error'),
      _ => (Icons.search_off, 'Unmatched'),
    };

    final candidateTitle = candidate['title']?.toString();
    final candidateArtist = candidate['artist']?.toString();
    final sourceLabel = candidate['sourceType'] == 'youtube_music_song'
        ? 'YouTube Music'
        : 'YouTube fallback';
    final unmatchedReason = result['unmatchedReason']?.toString();

    return ListTile(
      leading: Icon(icon),
      title: Text(
        result['sourceTitle']?.toString() ?? 'Unknown track',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        candidateTitle == null
            ? '${result['sourceArtist'] ?? ''} • $label${unmatchedReason == null ? '' : '\n$unmatchedReason'}'
            : '$candidateArtist — $candidateTitle\n$label • ${(score * 100).round()}% • $sourceLabel',
        maxLines: candidateTitle == null && unmatchedReason != null ? 3 : 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: candidateTitle != null || unmatchedReason != null,
    );
  }
}
