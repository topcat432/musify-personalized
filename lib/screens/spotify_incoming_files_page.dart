import 'dart:async';
import 'package:flutter/material.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/services/spotify_android_deflate_decoder.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/services/spotify_incoming_file_inbox.dart';
import 'package:musify/services/spotify_incoming_file_service.dart';
import 'package:musify/widgets/personalized_ui.dart';

class SpotifyIncomingFilesPage extends StatefulWidget {
  const SpotifyIncomingFilesPage({super.key, required this.service});
  final SpotifyIncomingFileService service;
  @override
  State<SpotifyIncomingFilesPage> createState() =>
      _SpotifyIncomingFilesPageState();
}

class _SpotifyIncomingFilesPageState extends State<SpotifyIncomingFilesPage> {
  SpotifyIncomingFileLease? _lease;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    if (_lease != null) unawaited(widget.service.finish(_lease!));
    super.dispose();
  }

  Future<void> _open(SpotifyIncomingFile file) async {
    if (_lease != null) return;
    final lease = widget.service.inbox.begin(file.id);
    setState(() { _lease = lease; _error = null; });
    await _preview(lease);
  }

  Future<void> _preview(SpotifyIncomingFileLease lease) async {
    if (!identical(_lease, lease)) return;
    setState(() => _error = null);
    var reviewReturned = false;
    try {
      final preview = await widget.service.inbox.readPreview(
        lease,
        openStream: widget.service.openStream,
        decodeDeflate: SpotifyAndroidDeflateDecoder.decode,
        chooseArchiveEntry: (entries) => showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Choose a song list from this ZIP'),
            children: [
              for (final entry in entries)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, entry),
                  child: Text(entry),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || !identical(_lease, lease)) return;
      await Navigator.of(context).push(
        personalizedPageRoute<void>(
          builder: (_) => SpotifyImportPage(initialPreview: preview),
        ),
      );
      reviewReturned = true;
    } on SpotifyImportException catch (error) {
      if (mounted && identical(_lease, lease))
        setState(() => _error = error.message);
    } catch (_) {
      if (mounted && identical(_lease, lease))
        setState(
          () => _error =
              'The incoming file could not be previewed. Try sharing it again.',
        );
    } finally {
      // A failed read remains explicitly retryable; completed review or leaving
      // releases only this lease. A stale completion cannot release its successor.
      if (reviewReturned || !mounted || !identical(_lease, lease)) {
        await widget.service.finish(lease);
        if (mounted && identical(_lease, lease)) setState(() => _lease = null);
      }
    }
  }

  void _cancel() {
    final lease = _lease;
    if (lease == null) return;
    setState(() => _lease = null);
    unawaited(widget.service.finish(lease));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Incoming song lists')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Preview a local file before saving. Your current import stays intact until Save and continue.',
        ),
        if (widget.service.notice != null || _error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: PersonalizedStatusBanner(
              tone: PersonalizedStatusTone.error,
              title: 'Current import retained',
              message: _error ?? widget.service.notice!,
            ),
          ),
        if (_lease != null)
          ListTile(
            title: Text(_lease!.file.name),
            subtitle: const Text('Reading or reviewing this file'),
            trailing: Wrap(children: [
              if (_error != null) TextButton(onPressed: () => _preview(_lease!), child: const Text('Retry preview')),
              TextButton(onPressed: _cancel, child: const Text('Cancel read')),
            ]),
          ),
        for (final file in widget.service.inbox.pending)
          ListTile(
            title: Text(file.name),
            subtitle: Text(
              file.size == null
                  ? 'Size unknown; read is limited to 8 MiB'
                  : '${file.size} bytes',
            ),
            trailing: Wrap(
              children: [
                TextButton(
                  onPressed: _lease == null ? () => _open(file) : null,
                  child: const Text('Preview'),
                ),
                IconButton(
                  tooltip: 'Dismiss file',
                  onPressed: () => widget.service.dismiss(file.id),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (widget.service.notice != null) TextButton(onPressed: widget.service.acknowledgeNotice, child: const Text('Dismiss notice')),
      if (_lease == null && widget.service.inbox.pending.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('No pending song-list files.'),
          ),
      ],
    ),
  );
}

/// Non-interrupting arrival notice. It never opens or saves a source by itself.
class SpotifyIncomingFileNotice extends StatelessWidget {
  const SpotifyIncomingFileNotice({
    super.key,
    required this.service,
    required this.onReview,
  });
  final SpotifyIncomingFileService service;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final count = service.inbox.pending.length;
      if (count == 0 && service.notice == null) return const SizedBox.shrink();
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.file_open_outlined),
              title: Text(
                count == 0
                    ? 'Incoming file needs review'
                    : '$count incoming song-list file${count == 1 ? '' : 's'}',
              ),
              trailing: TextButton(
                onPressed: onReview,
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
    },
  );
}
