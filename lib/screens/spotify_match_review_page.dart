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
      final items = await _service.loadReviewItems();
      if (!mounted) return;
      setState(() {
        // Keep a growable UI-owned copy. Service results may originate from a
        // fixed-length list, but accepted/rejected rows must disappear from
        // this screen immediately.
        _items = List<Map<String, dynamic>>.of(items, growable: true);
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

  Future<void> _resolve(
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

      // Build a new growable list instead of mutating the list returned by the
      // service. This avoids Unsupported operation errors from fixed-length
      // Dart lists while preserving the already-saved review decision.
      final remainingItems = _items
          .where((candidate) => _rowKey(candidate) != rowKey)
          .toList(growable: true);
      setState(() {
        _items = remainingItems;
        _selectedAlternativeIndex.remove(rowKey);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyRows.remove(rowKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _loading ? 'Review uncertain matches' : 'Review (${_items.length})',
        ),
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
                        'These tracks were close enough to keep, but not safe enough to accept automatically. Pick the correct source or mark that none of the suggestions are right. Decisions save immediately.',
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
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
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
                              'No uncertain matches are waiting right now.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    for (final item in _items) ...[
                      const SizedBox(height: 12),
                      _ReviewCard(
                        item: item,
                        selectedIndex:
                            _selectedAlternativeIndex[_rowKey(item)] ?? 0,
                        busy: _busyRows.contains(_rowKey(item)),
                        onSelected: (index) => setState(
                          () => _selectedAlternativeIndex[_rowKey(item)] =
                              index,
                        ),
                        onAccept: () => _resolve(item, accept: true),
                        onReject: () => _resolve(item, accept: false),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.selectedIndex,
    required this.busy,
    required this.onSelected,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final int selectedIndex;
  final bool busy;
  final ValueChanged<int> onSelected;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final alternatives = _SpotifyMatchReviewPageState._alternatives(item);
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
            Text(
              item['sourceArtist']?.toString() ?? 'Unknown artist',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if ((item['sourceAlbum']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item['sourceAlbum'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: 24),
            if (alternatives.isEmpty)
              const Text('No usable alternatives were saved for this track.')
            else
              for (final entry in alternatives.indexed)
                _AlternativeTile(
                  alternative: entry.$2,
                  selected: entry.$1 == selectedIndex,
                  onTap: () => onSelected(entry.$1),
                ),
            const SizedBox(height: 12),
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
                    onPressed: busy || alternatives.isEmpty ? null : onAccept,
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
        ? List<String>.from(
            (evidence['reasons'] as List).map((reason) => reason.toString()),
          )
        : const <String>[];

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
                    '${(score * 100).round()}% confidence${reasons.isEmpty ? '' : ' • ${reasons.take(2).join(' • ')}'}',
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
