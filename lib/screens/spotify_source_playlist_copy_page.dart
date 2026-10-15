import 'dart:async';

import 'package:flutter/material.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/widgets/personalized_ui.dart';

class SpotifySourcePlaylistCopyPage extends StatefulWidget {
  const SpotifySourcePlaylistCopyPage({required this.sourcePosition, super.key,
    this.service = const SpotifyImportDestinationService()});
  final int sourcePosition;
  final SpotifyImportDestinationService service;
  @override
  State<SpotifySourcePlaylistCopyPage> createState() => _SpotifySourcePlaylistCopyPageState();
}

class _SpotifySourcePlaylistCopyPageState extends State<SpotifySourcePlaylistCopyPage> {
  SpotifyPlaylistCopyPreview? _preview;
  SpotifyPlaylistCopyResult? _result;
  String? _message;
  var _busy = false;
  var _additional = false;
  @override
  void initState() { super.initState(); unawaited(_load()); }

  Future<void> _load({bool additional = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; _preview = null; _result = null; _additional = additional; });
    try {
      final value = await widget.service.previewSourcePlaylistCopy(widget.sourcePosition, additionalCopy: additional);
      if (mounted) setState(() => _preview = value);
    } catch (error) {
      if (mounted) setState(() => _message = error is StateError ? error.message :
        'This copy cannot be verified. Existing playlists and source membership were retained.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (_busy || preview == null || _result != null) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await widget.service.createSourcePlaylistCopy(preview);
      if (mounted) setState(() { _result = result;
        _message = result.trackingRecorded
          ? '${result.created ? 'Created' : 'Verified existing copy'} "${result.destinationTitle}". ${result.slotCount} playlist entries, ${result.uniqueRecordingCount} unique recordings.'
          : 'Playlist "${result.destinationTitle}" is saved, but verification is incomplete. Review the Library before retrying; no additional copy was created.';
      });
    } catch (error) {
      if (mounted) setState(() { _preview = null; _message = error is StateError ? error.message :
        'Creation could not be verified. Review the Library and the earlier attempt before retrying.'; });
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist copy')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (preview != null) ...[
              Text(preview.sourceName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${preview.slotCount} playlist entries · ${preview.uniqueRecordingCount} unique recordings · ${preview.slotCount - preview.uniqueRecordingCount} repeated ${preview.slotCount - preview.uniqueRecordingCount == 1 ? 'entry' : 'entries'}'),
              const SizedBox(height: 12),
              Text('Destination: ${preview.title}'),
              const SizedBox(height: 8),
              const Text('Every source entry uses your selected recording in original source order, including repeats. Existing playlists and manual edits are kept. This does not synchronize later changes or advance newly resolved tracking.'),
              if (preview.existingCompleted) const PersonalizedStatusBanner(
                title: 'Copy already exists', message: 'Confirmation leaves its current name, location and contents unchanged.'),
              if (preview.recoveringPending) const PersonalizedStatusBanner(
                title: 'Verify a saved copy', message: 'Confirmation checks the existing entries and finishes their audit. It will not create or rewrite a playlist.'),
              if (_additional) const PersonalizedStatusBanner(
                title: 'Another independent copy', message: 'This confirmation creates a separate new playlist. Earlier copies and their edits are kept.'),
            ],
            if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            if (_message != null) PersonalizedStatusBanner(title: _result == null ? 'Source copy retained for review' : 'Source copy result',
              message: _message!, tone: _result?.trackingRecorded == true ? PersonalizedStatusTone.success : PersonalizedStatusTone.warning),
          ],
        ))),
        if (preview != null) SliverList.builder(itemCount: preview.songs.length, itemBuilder: (context, index) {
          final song = preview.songs[index];
          return ListTile(leading: Text('${index + 1}'), title: Text(song['title']?.toString() ?? 'Selected recording'),
            subtitle: Text(song['artist']?.toString() ?? ''),);
        }),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (preview != null && _result == null) FilledButton(onPressed: _busy ? null : _confirm,
            child: Text(preview.existingCompleted ? 'Verify existing copy' : preview.recoveringPending ? 'Verify saved copy' : 'Create playlist copy')),
          if (!_busy && (preview?.existingCompleted == true || _result?.trackingRecorded == true || (_preview == null && _message != null)))
            OutlinedButton(onPressed: () => _load(additional: true), child: const Text('Review another independent copy')),
          if (!_busy && (_result?.trackingRecorded == false || (_preview == null && _message != null)))
            OutlinedButton(onPressed: () => _load(), child: const Text('Reload source review')),
          TextButton(onPressed: _busy ? null : () => Navigator.maybePop(context), child: Text(_result == null ? 'Cancel' : 'Done')),
        ],
      ))),
    );
  }
}
