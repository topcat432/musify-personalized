/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/spotify_csv_importer.dart';

class SpotifyImportPage extends StatefulWidget {
  const SpotifyImportPage({super.key});

  @override
  State<SpotifyImportPage> createState() => _SpotifyImportPageState();
}

class _SpotifyImportPageState extends State<SpotifyImportPage> {
  SpotifyImportPreview? _preview;
  String? _errorMessage;
  bool _isReading = false;
  bool _isSaving = false;
  bool _saved = false;

  Future<void> _pickCsv() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
      _saved = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final selectedFile = result.files.single;
      Uint8List? bytes = selectedFile.bytes;
      if (bytes == null && selectedFile.path != null) {
        bytes = await File(selectedFile.path!).readAsBytes();
      }
      if (bytes == null) {
        throw const SpotifyImportException(
          'Musify could not read the selected file.',
        );
      }

      final preview = SpotifyCsvImporter.parseBytes(
        bytes,
        fileName: selectedFile.name,
      );

      if (!mounted) return;
      setState(() => _preview = preview);
    } on SpotifyImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _errorMessage = 'The selected CSV could not be imported.';
      });
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _saveImport() async {
    final preview = _preview;
    if (preview == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final importedAt = DateTime.now().toUtc();
      await addOrUpdateData<List<Map<String, dynamic>>>(
        'user',
        'spotifyImportTracks',
        preview.tracks.map((track) => track.toJson()).toList(growable: false),
      );
      await addOrUpdateData<Map<String, dynamic>>(
        'user',
        'spotifyImportMetadata',
        {
          'version': 1,
          'fileName': preview.fileName,
          'format': preview.format,
          'validTrackCount': preview.tracks.length,
          'rejectedRowCount': preview.rejectedRows.length,
          'totalDataRows': preview.totalDataRows,
          'importedAt': importedAt.toIso8601String(),
          'matchingStatus': 'not_started',
          'nextTrackIndex': 0,
        },
      );

      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${preview.tracks.length} Spotify tracks saved for matching.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The import could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Spotify data')),
      body: ListView(
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
                        FluentIcons.arrow_upload_24_filled,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Spotify CSV importer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select your Spotify or Soundiiz CSV. This first step validates and stores the tracks locally; it does not search or change your Musify library yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isReading ? null : _pickCsv,
                      icon: _isReading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(FluentIcons.document_24_regular),
                      label: Text(_isReading ? 'Reading CSV…' : 'Choose CSV file'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      FluentIcons.error_circle_24_filled,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 12),
            _ImportSummaryCard(preview: preview, saved: _saved),
            const SizedBox(height: 12),
            Text(
              'Track preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final entry in preview.tracks.take(20).indexed)
                    ListTile(
                      leading: CircleAvatar(child: Text('${entry.$1 + 1}')),
                      title: Text(
                        entry.$2.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        entry.$2.album.isEmpty
                            ? entry.$2.artist
                            : '${entry.$2.artist} • ${entry.$2.album}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (preview.tracks.length > 20)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Showing 20 of ${preview.tracks.length} valid tracks.',
                      ),
                    ),
                ],
              ),
            ),
            if (preview.rejectedRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text(
                  '${preview.rejectedRows.length} rejected row${preview.rejectedRows.length == 1 ? '' : 's'}',
                ),
                children: [
                  for (final rejected in preview.rejectedRows.take(25))
                    ListTile(
                      dense: true,
                      title: Text('CSV row ${rejected.sourceRow}'),
                      subtitle: Text(rejected.reason),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveImport,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _saved
                            ? FluentIcons.checkmark_circle_24_filled
                            : FluentIcons.save_24_regular,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving…'
                      : _saved
                      ? 'Import saved'
                      : 'Save tracks for matching',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.preview, required this.saved});

  final SpotifyImportPreview preview;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  saved
                      ? FluentIcons.checkmark_circle_24_filled
                      : FluentIcons.document_checkmark_24_filled,
                  color: saved ? Colors.green : colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    saved ? 'Validated and saved' : 'CSV validated',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'File', value: preview.fileName),
            _SummaryRow(label: 'Detected format', value: preview.format),
            _SummaryRow(
              label: 'Valid tracks',
              value: preview.tracks.length.toString(),
            ),
            _SummaryRow(
              label: 'Rejected rows',
              value: preview.rejectedRows.length.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
