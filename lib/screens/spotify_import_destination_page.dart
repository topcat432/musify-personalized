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
  const SpotifyImportDestinationPage({super.key});

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
    _load();
  }

  @override
  void dispose() {
    _countController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
        _countController.text = snapshot.resolvedSongs.length.toString();
        if (_playlistNameController.text.trim().isEmpty) {
          _playlistNameController.text = snapshot.sourceName;
        }
        if (_existingPlaylistId == null &&
            snapshot.customPlaylists.isNotEmpty) {
          _existingPlaylistId = snapshot.customPlaylists.first['ytid']
              ?.toString();
        }
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
        title: const Text('Send these songs?'),
        content: Text(
          '${preview.selectedCount} resolved songs selected.\n'
          '${preview.newCount} will be added.\n'
          '${preview.alreadyPresentCount} are already there.\n'
          '${preview.unresolvedCount} unmatched songs will stay in review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send songs'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Choose destination')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                const PersonalizedHero(
                  eyebrow: 'Final transfer step',
                  icon: Icons.move_to_inbox_rounded,
                  title: 'Send matched songs where you want them',
                  description:
                      'Choose all resolved songs or an exact amount, then send them to Liked Songs or a Musify playlist.',
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
                if (snapshot == null || snapshot.resolvedSongs.isEmpty)
                  const PersonalizedEmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'No matched songs are ready',
                    description:
                        'Import and match songs first. Unmatched songs remain available for manual review.',
                  )
                else ...[
                  PersonalizedSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PersonalizedSectionHeading(
                          title: snapshot.sourceName,
                          description:
                              '${snapshot.resolvedSongs.length} unique resolved songs · ${snapshot.unresolvedCount} unmatched remain',
                        ),
                        if (snapshot.duplicateMatchCount > 0) ...[
                          const SizedBox(height: 12),
                          PersonalizedStatusBanner(
                            message:
                                '${snapshot.duplicateMatchCount} duplicate source rows share an existing resolved song and will not be added twice.',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const PersonalizedSectionHeading(
                    title: 'How many songs?',
                    description:
                        'Source order is preserved. Nothing unmatched is moved.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'All ${snapshot.resolvedSongs.length} resolved',
                        ),
                        selected: _useAll,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _useAll = true),
                      ),
                      ChoiceChip(
                        label: const Text('Choose exact amount'),
                        selected: !_useAll,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _useAll = false),
                      ),
                    ],
                  ),
                  if (!_useAll) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Number of songs',
                        helperText:
                            'Enter 1 through ${snapshot.resolvedSongs.length}.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const PersonalizedSectionHeading(
                    title: 'Where should they go?',
                    description:
                        'Existing songs are detected before anything is written.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.favorite_rounded, size: 18),
                        label: const Text('Liked Songs'),
                        selected: _destination ==
                            SpotifyImportDestinationKind.likedSongs,
                        onSelected: _saving
                            ? null
                            : (_) => setState(
                                () => _destination =
                                    SpotifyImportDestinationKind.likedSongs,
                              ),
                      ),
                      ChoiceChip(
                        avatar: const Icon(
                          Icons.playlist_add_rounded,
                          size: 18,
                        ),
                        label: const Text('New playlist'),
                        selected: _destination ==
                            SpotifyImportDestinationKind.newPlaylist,
                        onSelected: _saving
                            ? null
                            : (_) => setState(
                                () => _destination =
                                    SpotifyImportDestinationKind.newPlaylist,
                              ),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.playlist_play, size: 18),
                        label: const Text('Existing playlist'),
                        selected: _destination ==
                            SpotifyImportDestinationKind.existingPlaylist,
                        onSelected:
                            _saving || snapshot.customPlaylists.isEmpty
                            ? null
                            : (_) => setState(
                                () => _destination = SpotifyImportDestinationKind
                                    .existingPlaylist,
                              ),
                      ),
                    ],
                  ),
                  if (_destination ==
                      SpotifyImportDestinationKind.newPlaylist) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _playlistNameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'New playlist name',
                      ),
                    ),
                  ],
                  if (_destination ==
                      SpotifyImportDestinationKind.existingPlaylist) ...[
                    const SizedBox(height: 12),
                    DropdownMenu<String>(
                      initialSelection: _existingPlaylistId,
                      enabled: !_saving,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Destination playlist'),
                      dropdownMenuEntries: snapshot.customPlaylists
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _route,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _saving ? 'Saving safely…' : 'Review transfer',
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
