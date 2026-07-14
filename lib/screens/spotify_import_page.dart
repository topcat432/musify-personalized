/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/spotify_csv_importer.dart';
import 'package:musify/widgets/personalized_ui.dart';

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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final selectedFile = result.files.single;
      var bytes = selectedFile.bytes;
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
      await deleteData('user', 'spotifyExcludedImportRows');

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
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const PersonalizedHero(
            eyebrow: 'Step 1 of 3',
            icon: Icons.file_upload_outlined,
            title: 'Start with your song list',
            description:
                'Choose a Spotify, Exportify, or Soundiiz CSV. Musify checks every row before anything is saved.',
          ),
          const SizedBox(height: 24),
          const PersonalizedSectionHeading(
            title: 'Source file',
            description: 'Only compatible .csv files can be selected.',
          ),
          const SizedBox(height: 12),
          _CsvPickerSurface(
            reading: _isReading,
            fileName: preview?.fileName,
            onPressed: _pickCsv,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            PersonalizedStatusBanner(
              tone: PersonalizedStatusTone.error,
              title: 'This file could not be read',
              message: _errorMessage!,
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 18),
            _ImportSummaryCard(preview: preview, saved: _saved),
            const SizedBox(height: 24),
            PersonalizedSectionHeading(
              title: 'Track preview',
              description: 'The first 20 validated rows from this file.',
              trailing: Text(
                '${preview.tracks.length}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            PersonalizedSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in preview.tracks.take(20).indexed)
                    _TrackPreviewRow(
                      index: entry.$1,
                      title: entry.$2.title,
                      subtitle: entry.$2.album.isEmpty
                          ? entry.$2.artist
                          : '${entry.$2.artist} • ${entry.$2.album}',
                      showDivider:
                          entry.$1 < preview.tracks.take(20).length - 1,
                    ),
                  if (preview.tracks.length > 20)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${preview.tracks.length - 20} more validated tracks',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (preview.rejectedRows.isNotEmpty) ...[
              const SizedBox(height: 14),
              PersonalizedSurface(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.report_gmailerrorred_rounded),
                  title: Text(
                    '${preview.rejectedRows.length} row${preview.rejectedRows.length == 1 ? '' : 's'} need attention',
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
              ),
            ],
            const SizedBox(height: 20),
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
                      ? 'Saved for matching'
                      : 'Save and continue',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saving here does not add anything to Favorites.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return PersonalizedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonalizedStatusBanner(
            tone: PersonalizedStatusTone.success,
            title: saved ? 'Ready for matching' : 'CSV validated',
            message: saved
                ? 'This validated song list is saved on your device.'
                : 'Review the counts below, then save this list.',
            icon: saved
                ? FluentIcons.checkmark_circle_24_filled
                : FluentIcons.document_checkmark_24_filled,
          ),
          const SizedBox(height: 18),
          Text(
            preview.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            preview.format,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PersonalizedMetric(
                  label: 'Valid tracks',
                  value: preview.tracks.length.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PersonalizedMetric(
                  label: 'Rejected rows',
                  value: preview.rejectedRows.length.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CsvPickerSurface extends StatelessWidget {
  const _CsvPickerSurface({
    required this.reading,
    required this.fileName,
    required this.onPressed,
  });

  final bool reading;
  final String? fileName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PersonalizedSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: SizedBox.square(
              dimension: 58,
              child: Icon(
                fileName == null
                    ? FluentIcons.document_24_regular
                    : FluentIcons.document_checkmark_24_filled,
                color: colors.onPrimaryContainer,
                size: 29,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fileName ?? 'Select a music export',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            fileName == null
                ? 'Your original file is never changed.'
                : 'Choose another file to replace this preview.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: reading ? null : onPressed,
            icon: reading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: Text(reading ? 'Checking file…' : 'Choose .csv file'),
          ),
        ],
      ),
    );
  }
}

class _TrackPreviewRow extends StatelessWidget {
  const _TrackPreviewRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.showDivider,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 46),
      ],
    );
  }
}
