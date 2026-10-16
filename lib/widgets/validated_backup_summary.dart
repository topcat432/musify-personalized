/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:flutter/material.dart';
import 'package:musify/services/musify_backup_service.dart';

class ValidatedBackupSummary extends StatelessWidget {
  const ValidatedBackupSummary({
    super.key,
    required this.sourceDescription,
    required this.summary,
  });

  final String sourceDescription;
  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metrics = <(String, int)>[
      ('Imported tracks', summary.importedTracks),
      ('Match results', summary.matchResults),
      ('Strong matches', summary.strongMatches),
      ('Needs review', summary.reviewItems),
      ('Unmatched', summary.unmatchedItems),
      if (summary.excludedItems > 0) ('Excluded', summary.excludedItems),
      ('Errors', summary.errorItems),
      ('Favorites', summary.favorites),
      ('Playlists', summary.playlists),
    ];

    // AlertDialog queries both intrinsic dimensions. Table supports those
    // queries while keeping equal metric columns; LayoutBuilder cannot.
    // The dialog constrains this finite width on narrower devices.
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: colors.primary,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Source',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sourceDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
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
          const SizedBox(height: 14),
          Table(
            children: [
              for (var index = 0; index < metrics.length; index += 2)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 8),
                      child: _BackupMetric(
                        label: metrics[index].$1,
                        value: metrics[index].$2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: index + 1 < metrics.length
                          ? _BackupMetric(
                              label: metrics[index + 1].$1,
                              value: metrics[index + 1].$2,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.undo_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Musify creates and verifies a rollback copy before replacing '
                  'live data. Continue only if these counts look correct.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupMetric extends StatelessWidget {
  const _BackupMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
