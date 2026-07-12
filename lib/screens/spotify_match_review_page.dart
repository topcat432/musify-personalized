/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_manual_match_page.dart';
import 'package:musify/services/spotify_track_matching_service.dart';

class SpotifyMatchReviewPage extends StatefulWidget {
  const SpotifyMatchReviewPage({super.key});

  @override
  State<SpotifyMatchReviewPage> createState() =>
      _SpotifyMatchReviewPageState();
}

class _SpotifyMatchReviewPageState extends State<SpotifyMatchReviewPage> {
  final _service = const SpotifyTrackMatchingService();
  final Map<String, int> _selectedAlternativeIndex = {};
  final Set<String> _busyRows = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = Hive.box('user').get('spotifyMatchResults');
      final items = raw is List
          ? raw
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .where(_needsResolution)
                .toList()
          : <Map<String, dynamic>>[];
      items.sort((left, right) {
        final leftRow = int.tryParse(left['sourceRow']?.toString() ?? '') ?? 0;
        final rightRow = int.tryParse(right['sourceRow']?.toString() ?? '') ?? 0;
        return leftRow.compareTo(rightRow);
      });

      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _resolveSuggested(
    Map<String, dynamic> item, {
    required bool accept,
  }) async {
    final rowKey = _rowKey(item);
    if (_busyRows.contains(rowKey)) return;

    final alternatives = _alternatives(item);
    final selectedIndex = _selectedAlternativeIndex[rowKey] ?? 0;
    final selectedAlternative = accept && alternatives.isNotEmpty
        ? alternatives[selectedIndex.clamp(0, alternatives.length - 1)]
        : null;

    setState(() {
      _busyRows.add(rowKey);
      _error = null;
    });

    try {
      await _service.resolveReviewItem(
        sourceRow: item['sourceRow'],
        accept: accept,
        selectedAlternative: selectedAlternative,
      );
      if (!mounted) return;
      setState(() {
        _items = _items
            .where((candidate) => _rowKey(candidate) != rowKey)
            .toList();
        _selectedAlternativeIndex.remove(rowKey);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyRows.remove(rowKey));
    }
  }

  Future<void> _searchManually(Map<String, dynamic> item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SpotifyManualMatchPage(item: item),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Resolve imported tracks' : 'Resolve (${_items.length})'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Review close suggestions, or search manually when the finder cannot identify the exact recording. Every saved decision is attached to the imported song and persists immediately.',
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
                        busy: _busyRows.contains(_rowKey(item)),
                        onSelected: (index) => setState(
                          () => _selectedAlternativeIndex[_rowKey(item)] = index,
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

  static bool _needsResolution(Map<String, dynamic> item) {
    final status = item['status'];
    return status == 'needs_review' ||
        status == 'unmatched' ||
        status == 'manual_unmatched' ||
        status == 'error';
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
    final canAcceptSuggestion = status == 'needs_review' && alternatives.isNotEmpty;
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
            if (reason != null) ...[
              const SizedBox(height: 10),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (canAcceptSuggestion) ...[
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
            if (status == 'needs_review') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      child: const Text('None are correct'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy || !canAcceptSuggestion ? null : onAccept,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept selected'),
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
