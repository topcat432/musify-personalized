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
import 'package:musify/widgets/personalized_ui.dart';

class SpotifyMatchReviewPage extends StatefulWidget {
  const SpotifyMatchReviewPage({super.key});

  @override
  State<SpotifyMatchReviewPage> createState() => _SpotifyMatchReviewPageState();
}

class _SpotifyMatchReviewPageState extends State<SpotifyMatchReviewPage> {
  final SpotifyReviewWorkflowService _service =
      const SpotifyReviewWorkflowService();
  final Map<String, int> _selectedAlternativeIndex = {};
  final Set<String> _busyRows = {};
  final Set<String> _removingRows = {};
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
      personalizedPageRoute<bool>(
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
      personalizedPageRoute<bool>(
        builder: (_) => SpotifyManualMatchPage(item: item),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _excludePermanently(Map<String, dynamic> item) async {
    final rowKey = _rowKey(item);
    if (_busyRows.contains(rowKey) || _rescueRunning) return;
    final title = item['sourceTitle']?.toString().trim();
    final confirmed = await showPersonalizedDestructiveConfirmation(
      context: context,
      title: 'Exclude “${title?.isNotEmpty == true ? title : 'this track'}”?',
      message:
          'This removes the track from review, rescue, and every destination for this import. It will not remove anything already in Liked Songs.',
      confirmLabel: 'Exclude',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyRows.add(rowKey);
      _error = null;
    });
    try {
      await _service.excludeItem(item: item);
      if (!mounted) return;
      setState(() {
        _busyRows.remove(rowKey);
        _removingRows.add(rowKey);
      });
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      final clusters = await _service.loadClusters();
      if (!mounted) return;
      setState(() {
        _items.removeWhere((candidate) => _rowKey(candidate) == rowKey);
        _clusters = clusters;
        _selectedAlternativeIndex.remove(rowKey);
        _removingRows.remove(rowKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track excluded from this import workflow.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyRows.remove(rowKey);
        _removingRows.remove(rowKey);
        _error = 'Track was not excluded. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount = _items
        .where((item) => item['status'] == 'needs_review')
        .length;
    final unmatchedCount = _items
        .where(
          (item) =>
              item['status'] == 'unmatched' ||
              item['status'] == 'manual_unmatched',
        )
        .length;
    final errorCount = _items.where((item) => item['status'] == 'error').length;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detailed review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _rescueRunning ? () async {} : _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  const PersonalizedHero(
                    eyebrow: 'Repair workspace',
                    icon: Icons.tune_rounded,
                    title: 'Resolve the hard cases',
                    description:
                        'Run a cautious rescue pass, move quickly through one-at-a-time review, or compare every candidate in detail.',
                    compact: true,
                  ),
                  const SizedBox(height: 18),
                  PersonalizedReveal(
                    delay: const Duration(milliseconds: 70),
                    child: PersonalizedSurface(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: PersonalizedMetric(
                              label: 'Review',
                              value: reviewCount.toString(),
                            ),
                          ),
                          Expanded(
                            child: PersonalizedMetric(
                              label: 'Unmatched',
                              value: unmatchedCount.toString(),
                            ),
                          ),
                          Expanded(
                            child: PersonalizedMetric(
                              label: 'Errors',
                              value: errorCount.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    PersonalizedStatusBanner(
                      tone: PersonalizedStatusTone.error,
                      title: 'Review paused',
                      message: _error!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const PersonalizedSectionHeading(
                    title: 'Recommended path',
                    description:
                        'Start with automation, then make only the decisions that still need you.',
                  ),
                  const SizedBox(height: 12),
                  PersonalizedSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StageHeading(
                          number: '01',
                          icon: Icons.auto_fix_high_rounded,
                          title: 'Automated rescue',
                          description:
                              'Retry unmatched tracks with stricter album-aware searches and promote only near-certain results.',
                        ),
                        if (_rescueProgress != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: _rescueProgress!.fraction,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_rescueProgress!.processed} of ${_rescueProgress!.total} checked · ${_rescueProgress!.promotedToStrong} strong · ${_rescueProgress!.promotedToReview} to review',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _items.isEmpty
                                ? null
                                : _rescueRunning
                                ? () => setState(
                                    () => _stopRescueRequested = true,
                                  )
                                : _runRescuePass,
                            icon: Icon(
                              _rescueRunning
                                  ? Icons.pause_rounded
                                  : Icons.auto_fix_high_rounded,
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
                  const SizedBox(height: 12),
                  PersonalizedSurface(
                    color: colors.primaryContainer.withValues(alpha: 0.52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StageHeading(
                          number: '02',
                          icon: Icons.swipe_rounded,
                          title: 'Quick review',
                          description:
                              'Hear a short preview and decide one track at a time. Every choice saves immediately.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _items.isEmpty || _rescueRunning
                                ? null
                                : _openSprint,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start quick review'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_clusters.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const PersonalizedSectionHeading(
                      title: 'Evidence groups',
                      description:
                          'Patterns Musify found across the unresolved queue.',
                    ),
                    const SizedBox(height: 12),
                    PersonalizedSurface(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final entry in _clusters.take(6).indexed) ...[
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              leading: Icon(
                                entry.$2.safeForBulkApproval
                                    ? Icons.verified_outlined
                                    : Icons.rule_rounded,
                                color: colors.primary,
                              ),
                              title: Text(
                                entry.$2.label,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                entry.$2.safeForBulkApproval
                                    ? 'Safe pattern · verify five examples to unlock grouped approval.'
                                    : 'Identity or version details still need manual care.',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              trailing: Text(
                                '${entry.$2.count}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (entry.$1 < _clusters.take(6).length - 1)
                              const Divider(height: 1, indent: 56),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PersonalizedSectionHeading(
                    title: 'Detailed queue',
                    description:
                        'Compare all saved candidates when a track needs closer inspection.',
                    trailing: Text(
                      '${_items.length}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_items.isEmpty) ...[
                    const SizedBox(height: 12),
                    const PersonalizedEmptyState(
                      icon: Icons.library_add_check_rounded,
                      title: 'Everything is resolved',
                      description:
                          'Every processed track currently has a saved source decision.',
                    ),
                  ] else
                    for (final item in _items)
                      AnimatedSize(
                        key: ValueKey(_rowKey(item)),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: _removingRows.contains(_rowKey(item))
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _ResolutionCard(
                                  item: item,
                                  selectedIndex:
                                      _selectedAlternativeIndex[_rowKey(item)] ??
                                      0,
                                  busy:
                                      _busyRows.contains(_rowKey(item)) ||
                                      _rescueRunning,
                                  onSelected: (index) => setState(
                                    () => _selectedAlternativeIndex[_rowKey(
                                      item,
                                    )] = index,
                                  ),
                                  onAccept: () =>
                                      _resolveSuggested(item, accept: true),
                                  onReject: () =>
                                      _resolveSuggested(item, accept: false),
                                  onManualSearch: () => _searchManually(item),
                                  onExclude: () => _excludePermanently(item),
                                ),
                              ),
                      ),
                ],
              ),
            ),
    );
  }

  static String _rowKey(Map<String, dynamic> item) =>
      item['sourceRow']?.toString() ??
      '${item['sourceArtist']}:${item['sourceTitle']}';

  static List<Map<String, dynamic>> _alternatives(Map<String, dynamic> item) {
    final raw = item['alternatives'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}

class _StageHeading extends StatelessWidget {
  const _StageHeading({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(15),
          ),
          child: SizedBox.square(
            dimension: 46,
            child: Icon(icon, color: colors.primary, size: 23),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
    required this.onExclude,
  });

  final Map<String, dynamic> item;
  final int selectedIndex;
  final bool busy;
  final ValueChanged<int> onSelected;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onManualSearch;
  final VoidCallback onExclude;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'unmatched';
    final alternatives = _SpotifyMatchReviewPageState._alternatives(item);
    final canAcceptSuggestion = alternatives.isNotEmpty;
    final reason =
        item['unmatchedReason']?.toString() ??
        item['error']?.toString() ??
        (status == 'manual_unmatched'
            ? 'Previously marked as having no correct suggestion.'
            : null);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PersonalizedReveal(
      offset: const Offset(0, 0.025),
      child: PersonalizedSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            'IMPORTED TRACK',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['sourceTitle']?.toString() ?? 'Unknown track',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item['sourceArtist']?.toString() ?? 'Unknown artist',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if ((item['sourceAlbum']?.toString() ?? '').isNotEmpty)
            Text(
              item['sourceAlbum'].toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            SpotifyReviewWorkflowService.clusterLabel(item),
            style: theme.textTheme.labelMedium?.copyWith(color: colors.primary),
          ),
          if (reason != null) ...[
            const SizedBox(height: 10),
            PersonalizedStatusBanner(message: reason),
          ],
          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Saved candidates',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (final entry in alternatives.indexed)
              _AlternativeTile(
                alternative: entry.$2,
                selected: entry.$1 == selectedIndex,
                onTap: () => onSelected(entry.$1),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onManualSearch,
                  icon: const Icon(Icons.manage_search_rounded, size: 19),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  label: const Text('No match'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy || !canAcceptSuggestion ? null : onAccept,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Accept selected match'),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            child: TextButton.icon(
              key: ValueKey(
                'exclude-${item['sourceRow'] ?? item['sourceTitle']}',
              ),
              onPressed: busy ? null : onExclude,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.delete_forever_outlined, size: 19),
              label: const Text('Exclude permanently'),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.68)
              : colors.surfaceContainerHigh.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 11),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate['title']?.toString() ?? 'Unknown candidate',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          candidate['artist']?.toString() ??
                              candidate['videoAuthor']?.toString() ??
                              'Unknown source',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${(score * 100).round()}% match${reasons.isEmpty ? '' : ' · $reasons'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
