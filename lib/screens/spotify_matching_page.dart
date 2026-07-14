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
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/spotify_track_matching_service.dart';
import 'package:musify/widgets/personalized_ui.dart';

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
      personalizedPageRoute<void>(
        builder: (_) => const SpotifyMatchReviewPage(),
      ),
    );
    await _load();
  }

  Future<void> _openQuickReview() async {
    if (_running) return;
    await Navigator.of(context).push<bool>(
      personalizedPageRoute<bool>(
        builder: (_) => const SpotifyReviewSprintPage(),
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Match tracks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                const PersonalizedHero(
                  eyebrow: 'Step 2 of 3',
                  icon: Icons.graphic_eq_rounded,
                  title: 'Find the right recordings',
                  description:
                      'Musify checks title, artist, album, duration, version, and source quality while saving a safe checkpoint as it works.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  PersonalizedStatusBanner(
                    tone: PersonalizedStatusTone.error,
                    title: 'Matching paused',
                    message: _error!,
                  ),
                ],
                const SizedBox(height: 20),
                if (snapshot == null || !snapshot.hasImport)
                  const PersonalizedEmptyState(
                    icon: Icons.file_present_outlined,
                    title: 'No saved import yet',
                    description:
                        'Return to the CSV importer and save a validated song list first.',
                  )
                else ...[
                  _ProgressCard(
                    snapshot: snapshot,
                    onReviewTap: snapshot.reviewCount > 0 && !_running
                        ? _openQuickReview
                        : null,
                    onUnmatchedTap: snapshot.unmatchedCount > 0 && !_running
                        ? _openResolutionQueue
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const PersonalizedSectionHeading(
                    title: 'Matching run',
                    description:
                        'Choose a comfortable batch. You can pause after the current track without losing progress.',
                  ),
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
                            ? Icons.check_rounded
                            : _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
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
                  if (_running && _unresolvedCount(snapshot) > 0) ...[
                    const SizedBox(height: 10),
                    const PersonalizedStatusBanner(
                      icon: Icons.sync_rounded,
                      message:
                          'Pause matching before reviewing tracks manually. Your checkpoint is already saved.',
                    ),
                  ],
                  if (_selectedRunSize == _allRemaining && !_running) ...[
                    const SizedBox(height: 10),
                    const PersonalizedStatusBanner(
                      icon: Icons.shield_outlined,
                      message:
                          'The full run works in safe 50-track sections and checkpoints every five tracks.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  PersonalizedSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PersonalizedSectionHeading(
                          title: 'Resolve what remains',
                          description:
                              'Review uncertain songs now or open the detailed comparison queue.',
                          trailing: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Text(
                                '${_unresolvedCount(snapshot)}',
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _unresolvedCount(snapshot) == 0 || _running
                                ? null
                                : _openQuickReview,
                            icon: const Icon(Icons.swipe_rounded),
                            label: Text(
                              _unresolvedCount(snapshot) == 0
                                  ? 'Nothing waiting for review'
                                  : 'Start quick review',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _unresolvedCount(snapshot) == 0 || _running
                                ? null
                                : _openResolutionQueue,
                            icon: const Icon(Icons.view_list_outlined),
                            label: const Text('Open detailed queue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.nextTrackIndex > 0 && !_running) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _restartMatching,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Restart with the newest matcher'),
                      ),
                    ),
                  ],
                  if (snapshot.recentResults.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const PersonalizedSectionHeading(
                      title: 'Recent matches',
                      description: 'The newest results from this run.',
                    ),
                    const SizedBox(height: 12),
                    PersonalizedSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final entry
                              in snapshot.recentResults.indexed) ...[
                            _ResultTile(result: entry.$2),
                            if (entry.$1 < snapshot.recentResults.length - 1)
                              const Divider(height: 1, indent: 66),
                          ],
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
    final colors = Theme.of(context).colorScheme;
    return PersonalizedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                allRemainingUnlocked
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allRemainingUnlocked
                      ? 'Full-library mode is unlocked because the sample passed its safety check.'
                      : 'Process at least 50 tracks with a strong match rate to unlock the full-library run.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.snapshot,
    required this.onReviewTap,
    required this.onUnmatchedTap,
  });

  final SpotifyMatchingSnapshot snapshot;
  final VoidCallback? onReviewTap;
  final VoidCallback? onUnmatchedTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PersonalizedSurface(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.82),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonalizedSectionHeading(
            title:
                '${snapshot.nextTrackIndex} of ${snapshot.totalTracks} processed',
            description: snapshot.isComplete
                ? 'Every imported track has passed through the matcher.'
                : '${snapshot.remainingCount} tracks remain in this run.',
            trailing: Text(
              '${(snapshot.progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: snapshot.progress,
              minHeight: 7,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _CountMetric(
                  label: 'Strong',
                  count: snapshot.matchedCount,
                ),
              ),
              Expanded(
                child: _CountMetric(
                  label: 'Review',
                  count: snapshot.reviewCount,
                  onTap: onReviewTap,
                ),
              ),
              Expanded(
                child: _CountMetric(
                  label: 'Unmatched',
                  count: snapshot.unmatchedCount,
                  onTap: onUnmatchedTap,
                ),
              ),
              if (snapshot.errorCount > 0)
                Expanded(
                  child: _CountMetric(
                    label: 'Errors',
                    count: snapshot.errorCount,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({
    required this.label,
    required this.count,
    this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
          child: Column(
            children: [
              Text(
                '$count',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onTap == null ? null : theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
      'excluded' => (Icons.delete_forever_outlined, 'Excluded from import'),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        child: SizedBox.square(
          dimension: 42,
          child: Icon(icon, color: colors.onPrimaryContainer, size: 21),
        ),
      ),
      title: Text(
        result['sourceTitle']?.toString() ?? 'Unknown track',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        candidateTitle == null
            ? '${result['sourceArtist'] ?? ''} • $label${unmatchedReason == null ? '' : '\n$unmatchedReason'}'
            : '$candidateArtist — $candidateTitle\n$label • ${(score * 100).round()}% • $sourceLabel',
        maxLines: candidateTitle == null && unmatchedReason != null ? 3 : 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      isThreeLine: candidateTitle != null || unmatchedReason != null,
    );
  }
}
