/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/widgets/personalized_ui.dart';

class SpotifyImportDestinationPage extends StatefulWidget {
  const SpotifyImportDestinationPage({super.key, this.initialSnapshot});

  /// Supplies deterministic data to screenshot previews without touching the
  /// user's Hive boxes. Production callers leave this null.
  final SpotifyImportDestinationSnapshot? initialSnapshot;

  @override
  State<SpotifyImportDestinationPage> createState() =>
      _SpotifyImportDestinationPageState();
}

class _SpotifyImportDestinationPageState
    extends State<SpotifyImportDestinationPage> {
  final _service = const SpotifyImportDestinationService();
  final _countController = TextEditingController();
  final _playlistNameController = TextEditingController();
  SpotifyImportDestinationSnapshot? _snapshot;
  SpotifyImportDestinationKind _destination =
      SpotifyImportDestinationKind.likedSongs;
  String? _existingPlaylistId;
  bool _useAll = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialSnapshot = widget.initialSnapshot;
    if (initialSnapshot != null) {
      _applySnapshot(initialSnapshot);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  void _applySnapshot(SpotifyImportDestinationSnapshot snapshot) {
    _snapshot = snapshot;
    _countController.text = snapshot.resolvedSongs.length.toString();
    if (_playlistNameController.text.trim().isEmpty) {
      _playlistNameController.text = snapshot.sourceName;
    }
    if (_existingPlaylistId == null && snapshot.customPlaylists.isNotEmpty) {
      _existingPlaylistId = snapshot.customPlaylists.first['ytid']?.toString();
    }
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _applySnapshot(snapshot);
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

  int _selectedCount(SpotifyImportDestinationSnapshot snapshot) {
    if (_useAll) return snapshot.resolvedSongs.length;
    final parsed = int.tryParse(_countController.text.trim()) ?? 0;
    return parsed.clamp(0, snapshot.resolvedSongs.length);
  }

  Future<void> _route() async {
    final snapshot = _snapshot;
    if (snapshot == null || _saving) return;
    final count = _selectedCount(snapshot);
    if (count == 0) {
      setState(() => _error = 'Choose at least one resolved song.');
      return;
    }
    if (_destination == SpotifyImportDestinationKind.newPlaylist &&
        _playlistNameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name for the new playlist.');
      return;
    }
    if (_destination == SpotifyImportDestinationKind.existingPlaylist &&
        _existingPlaylistId == null) {
      setState(() => _error = 'Choose an existing playlist.');
      return;
    }

    final preview = _service.preview(
      snapshot: snapshot,
      requestedCount: count,
      destinationKind: _destination,
      existingPlaylistId: _existingPlaylistId,
    );
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.move_to_inbox_rounded),
        title: const Text('Ready to transfer?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogMetric(
              value: preview.newCount.toString(),
              label: 'new songs will be added',
            ),
            const SizedBox(height: 10),
            _DialogMetric(
              value: preview.alreadyPresentCount.toString(),
              label: 'already there and will be skipped',
            ),
            if (preview.unresolvedCount > 0) ...[
              const SizedBox(height: 10),
              _DialogMetric(
                value: preview.unresolvedCount.toString(),
                label: 'unmatched songs stay available for review',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transfer songs'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _service.route(
        snapshot: snapshot,
        requestedCount: count,
        destinationKind: _destination,
        newPlaylistName: _playlistNameController.text,
        existingPlaylistId: _existingPlaylistId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.addedCount} songs added to ${result.destinationTitle}. '
            '${result.alreadyPresentCount} already present.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final readySnapshot = snapshot?.resolvedSongs.isNotEmpty == true
        ? snapshot
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose destination')),
      bottomNavigationBar: readySnapshot != null
          ? _TransferActionBar(
              selectedCount: _selectedCount(readySnapshot),
              saving: _saving,
              onPressed: _route,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                const PersonalizedHero(
                  eyebrow: 'Step 4 of 4',
                  icon: Icons.move_to_inbox_rounded,
                  title: 'Finish your music transfer',
                  description:
                      'Choose how many matched songs to move and exactly where they should appear in Musify.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  PersonalizedStatusBanner(
                    tone: PersonalizedStatusTone.error,
                    title: 'Transfer not completed',
                    message: _error!,
                  ),
                ],
                const SizedBox(height: 22),
                if (readySnapshot == null)
                  PersonalizedEmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'No matched songs are ready',
                    description:
                        'Import and match songs first. Unmatched songs remain available for manual review.',
                    action: _error == null
                        ? null
                        : OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                  )
                else ...[
                  _ImportSummary(snapshot: readySnapshot),
                  const SizedBox(height: 26),
                  const PersonalizedSectionHeading(
                    title: '1. Choose how many',
                    description:
                        'Songs stay in their original CSV order. Unmatched tracks are never moved.',
                  ),
                  const SizedBox(height: 12),
                  _SelectionCard(
                    icon: Icons.library_add_check_rounded,
                    title: 'Move every matched song',
                    description:
                        '${readySnapshot.resolvedSongs.length} unique songs are ready',
                    selected: _useAll,
                    enabled: !_saving,
                    onTap: () => setState(() => _useAll = true),
                  ),
                  const SizedBox(height: 10),
                  _SelectionCard(
                    icon: Icons.tune_rounded,
                    title: 'Choose an exact amount',
                    description: 'Move the first songs from this import',
                    selected: !_useAll,
                    enabled: !_saving,
                    onTap: () => setState(() => _useAll = false),
                  ),
                  if (!_useAll) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.numbers_rounded),
                        labelText: 'Number of songs',
                        helperText:
                            'Enter 1 through ${readySnapshot.resolvedSongs.length}.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const PersonalizedSectionHeading(
                    title: '2. Choose a destination',
                    description:
                        'Musify checks for duplicates before adding anything.',
                  ),
                  const SizedBox(height: 12),
                  _SelectionCard(
                    icon: Icons.favorite_rounded,
                    title: 'Liked Songs',
                    description: 'Add them to your heart collection',
                    selected: _destination ==
                        SpotifyImportDestinationKind.likedSongs,
                    enabled: !_saving,
                    onTap: () => setState(
                      () => _destination =
                          SpotifyImportDestinationKind.likedSongs,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SelectionCard(
                    icon: Icons.playlist_add_rounded,
                    title: 'Create a new playlist',
                    description: 'Keep this import together as its own playlist',
                    selected: _destination ==
                        SpotifyImportDestinationKind.newPlaylist,
                    enabled: !_saving,
                    onTap: () => setState(
                      () => _destination =
                          SpotifyImportDestinationKind.newPlaylist,
                    ),
                  ),
                  if (_destination ==
                      SpotifyImportDestinationKind.newPlaylist) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _playlistNameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.edit_rounded),
                        labelText: 'New playlist name',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _SelectionCard(
                    icon: Icons.playlist_play_rounded,
                    title: 'Add to an existing playlist',
                    description: readySnapshot.customPlaylists.isEmpty
                        ? 'No Musify playlists are available yet'
                        : 'Choose from ${readySnapshot.customPlaylists.length} Musify playlists',
                    selected: _destination ==
                        SpotifyImportDestinationKind.existingPlaylist,
                    enabled:
                        !_saving && readySnapshot.customPlaylists.isNotEmpty,
                    onTap: () => setState(
                      () => _destination =
                          SpotifyImportDestinationKind.existingPlaylist,
                    ),
                  ),
                  if (_destination ==
                      SpotifyImportDestinationKind.existingPlaylist) ...[
                    const SizedBox(height: 12),
                    DropdownMenu<String>(
                      initialSelection: _existingPlaylistId,
                      enabled: !_saving,
                      expandedInsets: EdgeInsets.zero,
                      leadingIcon: const Icon(Icons.queue_music_rounded),
                      label: const Text('Destination playlist'),
                      dropdownMenuEntries: readySnapshot.customPlaylists
                          .map(
                            (playlist) => DropdownMenuEntry<String>(
                              value: playlist['ytid'].toString(),
                              label:
                                  playlist['title']?.toString() ?? 'Playlist',
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) =>
                          setState(() => _existingPlaylistId = value),
                    ),
                  ],
                  if (readySnapshot.unresolvedCount > 0) ...[
                    const SizedBox(height: 22),
                    PersonalizedStatusBanner(
                      icon: Icons.bookmark_outline_rounded,
                      message:
                          '${readySnapshot.unresolvedCount} unmatched songs stay saved in review so you can resolve them later.',
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.snapshot});

  final SpotifyImportDestinationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PersonalizedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMPORT READY',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.sourceName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PersonalizedMetric(
                  label: 'Matched',
                  value: snapshot.resolvedSongs.length.toString(),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: PersonalizedMetric(
                  label: 'Unmatched',
                  value: snapshot.unresolvedCount.toString(),
                  icon: Icons.search_off_rounded,
                ),
              ),
              Expanded(
                child: PersonalizedMetric(
                  label: 'Duplicates',
                  value: snapshot.duplicateMatchCount.toString(),
                  icon: Icons.copy_all_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. $description',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.72)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.65)
                : colors.outlineVariant.withValues(alpha: 0.42),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.surface.withValues(alpha: 0.74)
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        icon,
                        size: 23,
                        color: enabled ? colors.primary : foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? colors.onSurfaceVariant
                                : foreground,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? colors.primary : foreground,
                    size: 23,
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

class _TransferActionBar extends StatelessWidget {
  const _TransferActionBar({
    required this.selectedCount,
    required this.saving,
    required this.onPressed,
  });

  final int selectedCount;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 10,
      shadowColor: colors.shadow.withValues(alpha: 0.18),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$selectedCount ${selectedCount == 1 ? 'song' : 'songs'} selected',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onPressed,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(saving ? 'Saving safely…' : 'Review transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogMetric extends StatelessWidget {
  const _DialogMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Text(label)),
      ],
    );
  }
}
