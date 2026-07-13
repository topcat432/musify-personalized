/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

class SpotifyMatchReviewPage extends StatefulWidget {
  const SpotifyMatchReviewPage({super.key});

  @override
  State<SpotifyMatchReviewPage> createState() =>
      _SpotifyMatchReviewPageState();
}

class _SpotifyMatchReviewPageState extends State<SpotifyMatchReviewPage> {
  final SpotifyReviewWorkflowService _service =
      const SpotifyReviewWorkflowService();
  final Map<String, int> _selectedAlternativeIndex = {};
  final Set<String> _busyRows = {};
  List<Map<String, dynamic>> _items = [];
  List<SpotifyReviewCluster> _clusters = [];
  SpotifyRescueProgress? _rescueProgress;
  bool _loading = true;
  bool _rescueRunning = false;
  bool _stopRescueRequested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.loadUnresolvedItems();
      final clusters = await _service.loadClusters();
      if (!mounted) return;
      setState(() {
        _items = items;
        _clusters = clusters;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _runRescuePass() async {
    if (_rescueRunning || _items.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run automated rescue pass?'),
        content: const Text(
          'The app will safely promote near-certain review items and retry unmatched or failed tracks using album-aware YouTube Music and official-audio searches. Existing strong and manually confirmed matches will not be changed. Progress saves every five tracks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Start rescue'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() {
      _rescueRunning = true;
      _stopRescueRequested = false;
      _rescueProgress = null;
      _error = null;
    });

    try {
      await _service.runRescuePass(
        shouldStop: () => _stopRescueRequested,
        onProgress: (progress) {
          if (mounted) setState(() => _rescueProgress = progress);
        },
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _rescueRunning = false;
          _stopRescueRequested = false;
        });
      }
    }
  }

  Future<void> _openSprint() async {
    if (_rescueRunning || _items.isEmpty) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const SpotifyReviewSprintPage(),
      ),
    );
    await _load();
  }

  Future<void> _resolveSuggested(
    Map<String, dynamic> item, {
    required bool accept,
  }) async {
    final rowKey = _rowKey(item);
    if (_busyRows.contains(rowKey) || _rescueRunning) return;
    final alternatives = _alternatives(item);
    final selectedIndex = _selectedAlternativeIndex[rowKey] ?? 0;
    final selected = accept && alternatives.isNotEmpty
        ? alternatives[selectedIndex.clamp(0, alternatives.length - 1)]
        : null;

    setState(() {
      _busyRows.add(rowKey);
      _error = null;
    });

    try {
      final result = await _service.resolveItem(
        item: item,
        accept: accept,
        selectedAlternative: selected,
      );
      if (!mounted) return;
      if (result.duplicatesApplied > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Also resolved ${result.duplicatesApplied} exact-ISRC duplicate${result.duplicatesApplied == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyRows.remove(rowKey));
    }
  }

  Future<void> _searchManually(Map<String, dynamic> item) async {
    if (_rescueRunning) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SpotifyManualMatchPage(item: item),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount =
        _items.where((item) => item['status'] == 'needs_review').length;
    final unmatchedCount = _items
        .where(
          (item) =>
              item['status'] == 'unmatched' ||
              item['status'] == 'manual_unmatched',
        )
        .length;
    final errorCount = _items.where((item) => item['status'] == 'error').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _loading ? 'Resolve imported tracks' : 'Resolve (${_items.length})',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _rescueRunning ? () async {} : _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finish the import without grinding through every track',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Run the rescue pass first. Then use Review Sprint for fast autoplay decisions. Evidence clusters unlock guarded bulk approval only after you personally verify five matching examples without a rejection.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.help, size: 18),
                        label: Text('Review $reviewCount'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.search_off, size: 18),
                        label: Text('Unmatched $unmatchedCount'),
                      ),
                      if (errorCount > 0)
                        Chip(
                          avatar: const Icon(Icons.error, size: 18),
                          label: Text('Errors $errorCount'),
                        ),
                    ],
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. Automated rescue',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Promotes only strict near-certain patterns and retries unmatched tracks with additional album-aware searches.',
                          ),
                          if (_rescueProgress != null) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _rescueProgress!.fraction,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_rescueProgress!.processed} of ${_rescueProgress!.total} checked • ${_rescueProgress!.promotedToStrong} strong • ${_rescueProgress!.promotedToReview} moved to review',
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _items.isEmpty
                                  ? null
                                  : _rescueRunning
                                  ? () => setState(
                                      () => _stopRescueRequested = true,
                                    )
                                  : _runRescuePass,
                              icon: Icon(
                                _rescueRunning ? Icons.pause : Icons.auto_fix_high,
                              ),
                              label: Text(
                                _rescueRunning
                                    ? _stopRescueRequested
                                          ? 'Pausing after this track…'
                                          : 'Pause rescue safely'
                                    : 'Run rescue pass',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. Review Sprint',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Shows one track at a time, pre-resolves upcoming streams, auto-plays a 12-second preview, supports quick gestures, and saves every decision immediately.',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _items.isEmpty || _rescueRunning
                                  ? null
                                  : _openSprint,
                              icon: const Icon(Icons.bolt),
                              label: const Text('Start Review Sprint'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_clusters.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Largest evidence clusters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final cluster in _clusters.take(6)) ...[
                      Card(
                        child: ListTile(
                          leading: Icon(
                            cluster.safeForBulkApproval
                                ? Icons.verified_outlined
                                : Icons.rule,
                          ),
                          title: Text(cluster.label),
                          subtitle: Text(
                            cluster.safeForBulkApproval
                                ? 'Strictly safe pattern; audit five examples in Review Sprint to unlock guarded bulk approval.'
                                : 'This pattern remains manual because one or more identity or version signals need care.',
                          ),
                          trailing: Text('${cluster.count}'),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Detailed queue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use this slower view when you want to compare several candidates at once.',
                  ),
                  if (_items.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 42),
                            SizedBox(height: 10),
                            Text(
                              'Every processed track currently has a resolved source.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    for (final item in _items) ...[
                      const SizedBox(height: 12),
                      _ResolutionCard(
                        item: item,
                        selectedIndex:
                            _selectedAlternativeIndex[_rowKey(item)] ?? 0,
                        busy: _busyRows.contains(_rowKey(item)) || _rescueRunning,
                        onSelected: (index) => setState(
                          () =>
                              _selectedAlternativeIndex[_rowKey(item)] = index,
                        ),
                        onAccept: () =>
                            _resolveSuggested(item, accept: true),
                        onReject: () =>
                            _resolveSuggested(item, accept: false),
                        onManualSearch: () => _searchManually(item),
                      ),
                    ],
                ],
              ),
            ),
    );
  }

  static String _rowKey(Map<String, dynamic> item) =>
      item['sourceRow']?.toString() ??
      '${item['sourceArtist']}:${item['sourceTitle']}';

  static List<Map<String, dynamic>> _alternatives(
    Map<String, dynamic> item,
  ) {
    final raw = item['alternatives'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.item,
    required this.selectedIndex,
    required this.busy,
    required this.onSelected,
    required this.onAccept,
    required this.onReject,
    required this.onManualSearch,
  });

  final Map<String, dynamic> item;
  final int selectedIndex;
  final bool busy;
  final ValueChanged<int> onSelected;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onManualSearch;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'unmatched';
    final alternatives = _SpotifyMatchReviewPageState._alternatives(item);
    final canAcceptSuggestion = alternatives.isNotEmpty;
    final reason = item['unmatchedReason']?.toString() ??
        item['error']?.toString() ??
        (status == 'manual_unmatched'
            ? 'Previously marked as having no correct suggestion.'
            : null);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['sourceTitle']?.toString() ?? 'Unknown track',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(item['sourceArtist']?.toString() ?? 'Unknown artist'),
            if ((item['sourceAlbum']?.toString() ?? '').isNotEmpty)
              Text(
                item['sourceAlbum'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              SpotifyReviewWorkflowService.clusterLabel(item),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (alternatives.isNotEmpty) ...[
              const Divider(height: 24),
              for (final entry in alternatives.indexed)
                _AlternativeTile(
                  alternative: entry.$2,
                  selected: entry.$1 == selectedIndex,
                  onTap: () => onSelected(entry.$1),
                ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onManualSearch,
                icon: const Icon(Icons.manage_search),
                label: const Text('Search manually'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || !canAcceptSuggestion ? null : onAccept,
                icon: const Icon(Icons.check),
                label: const Text('Accept selected match'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text('None are correct'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.alternative,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> alternative;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final candidate = alternative['candidate'] is Map
        ? Map<String, dynamic>.from(alternative['candidate'] as Map)
        : <String, dynamic>{};
    final evidence = alternative['evidence'] is Map
        ? Map<String, dynamic>.from(alternative['evidence'] as Map)
        : <String, dynamic>{};
    final score = alternative['score'] is num
        ? (alternative['score'] as num).toDouble()
        : 0.0;
    final reasons = evidence['reasons'] is List
        ? (evidence['reasons'] as List)
            .map((reason) => reason.toString())
            .take(2)
            .join(' • ')
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate['title']?.toString() ?? 'Unknown candidate',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate['artist']?.toString() ??
                        candidate['videoAuthor']?.toString() ??
                        'Unknown source',
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${(score * 100).round()}% confidence${reasons.isEmpty ? '' : ' • $reasons'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
