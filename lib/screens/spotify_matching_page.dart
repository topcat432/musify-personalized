/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

class SpotifyMatchingPage extends StatefulWidget {
  const SpotifyMatchingPage({super.key});

  @override
  State<SpotifyMatchingPage> createState() => _SpotifyMatchingPageState();
}

class _SpotifyMatchingPageState extends State<SpotifyMatchingPage> {
  final _service = const SpotifyTrackMatchingService();
  SpotifyMatchingSnapshot? _snapshot;
  bool _loading = true;
  bool _running = false;
  bool _stopRequested = false;
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runNextBatch() async {
    if (_running) return;
    setState(() {
      _running = true;
      _stopRequested = false;
      _error = null;
    });

    try {
      final snapshot = await _service.matchNextBatch(
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
                            Text(
                              'Safe track matching',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Each imported record is compared against YouTube results using title, artist, duration, source quality, and long-form-content checks. Strong matches are saved automatically; uncertain choices remain separated for review.',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'This pilot processes 25 tracks at a time and saves a checkpoint every five tracks. It does not add anything to Favorites or playlists yet.',
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: snapshot.isComplete
                          ? null
                          : _running
                          ? () => setState(() => _stopRequested = true)
                          : _runNextBatch,
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
                            : 'Match next 25 tracks',
                      ),
                    ),
                  ),
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
      'needs_review' => (Icons.help, 'Needs review'),
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
