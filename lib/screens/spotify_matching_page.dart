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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runSelectedBatch() async {
    if (_running) return;
    final snapshotBeforeRun = _snapshot;
    if (snapshotBeforeRun == null || snapshotBeforeRun.isComplete) return;

    final batchSize = _selectedRunSize == _allRemaining
        ? snapshotBeforeRun.remainingCount
        : _selectedRunSize;

    setState(() {
      _running = true;
      _stopRequested = false;
      _error = null;
    });

    try {
      final snapshot = await _service.matchNextBatch(
        batchSize: batchSize,
        shouldStop: () => _stopRequested,
        onProgress: (progress) {
          if (mounted) setState(() => _snapshot = progress);
        },
      );
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
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

  Future<void> _openReviewQueue() async {
    if (_running) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SpotifyMatchReviewPage(),
      ),
    );
    await _load();
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
                              Icons.manage_search,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Safe track matching',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Each imported record is compared against YouTube results using title, artist, duration, source quality, and long-form-content checks. Strong matches are staged automatically; uncertain choices can be reviewed as soon as they appear.',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Progress is saved every five tracks. Nothing is added to Favorites or playlists during this validation pass.',
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
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
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
                      onPressed: snapshot.reviewCount == 0 || _running
                          ? null
                          : _openReviewQueue,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        snapshot.reviewCount == 0
                            ? 'No uncertain matches waiting'
                            : 'Review ${snapshot.reviewCount} uncertain matches now',
                      ),
                    ),
                  ),
                  if (_running && snapshot.reviewCount > 0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Tap Pause safely, then open the review queue. Matching resumes from the saved checkpoint afterward.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_selectedRunSize == _allRemaining && !_running) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'All remaining may take a while. Keep the app open; you can pause safely at any time.',
                      textAlign: TextAlign.center,
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
}

class _RunControlsCard extends StatelessWidget {
  const _RunControlsCard({
    required this.selectedRunSize,
    required this.allRemainingValue,
    required this.remainingCount,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedRunSize;
  final int allRemainingValue;
  final int remainingCount;
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('25'),
                  selected: selectedRunSize == 25,
                  onSelected: enabled ? (_) => onSelected(25) : null,
                ),
                ChoiceChip(
                  label: const Text('100'),
                  selected: selectedRunSize == 100,
                  onSelected: enabled ? (_) => onSelected(100) : null,
                ),
                ChoiceChip(
                  label: Text('All remaining ($remainingCount)'),
                  selected: selectedRunSize == allRemainingValue,
                  onSelected: enabled
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

    return ListTile(
      leading: Icon(icon),
      title: Text(
        result['sourceTitle']?.toString() ?? 'Unknown track',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        candidateTitle == null
            ? '${result['sourceArtist'] ?? ''} • $label'
            : '$candidateArtist — $candidateTitle\n$label • ${(score * 100).round()}%',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: candidateTitle != null,
    );
  }
}
