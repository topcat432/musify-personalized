/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/widgets/personalized_ui.dart';

class SpotifyImportHubPage extends StatelessWidget {
  const SpotifyImportHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spotify import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const PersonalizedHero(
            eyebrow: 'Library transfer',
            icon: Icons.library_music_rounded,
            title: 'Bring your saved music with you',
            description:
                'Import a CSV, let Musify find the right recordings, then review only the tracks that need your judgment.',
          ),
          const SizedBox(height: 24),
          const PersonalizedSectionHeading(
            title: 'Your transfer',
            description: 'Continue from whichever stage you last completed.',
          ),
          const SizedBox(height: 12),
          PersonalizedSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _WorkflowStep(
                  number: '01',
                  icon: Icons.file_upload_outlined,
                  title: 'Choose your CSV',
                  description:
                      'Validate and save tracks from Spotify, Exportify, or Soundiiz.',
                  onPressed: () => Navigator.of(context).push(
                    personalizedPageRoute<void>(
                      builder: (_) => const SpotifyImportPage(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 76),
                _WorkflowStep(
                  number: '02',
                  icon: Icons.graphic_eq_rounded,
                  title: 'Find the recordings',
                  description: 'Resume catalog matching with safe checkpoints.',
                  onPressed: () => Navigator.of(context).push(
                    personalizedPageRoute<void>(
                      builder: (_) => const SpotifyMatchingPage(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 76),
                _WorkflowStep(
                  number: '03',
                  icon: Icons.swipe_rounded,
                  title: 'Review the uncertain tracks',
                  description:
                      'Preview one suggestion at a time and save each decision.',
                  onPressed: () => Navigator.of(context).push(
                    personalizedPageRoute<void>(
                      builder: (_) => const SpotifyReviewSprintPage(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 76),
                _WorkflowStep(
                  number: '04',
                  icon: Icons.move_to_inbox_rounded,
                  title: 'Choose a destination',
                  description:
                      'Send all or an exact number of resolved songs to Liked Songs or a playlist.',
                  onPressed: () => Navigator.of(context).push(
                    personalizedPageRoute<void>(
                      builder: (_) => const SpotifyImportDestinationPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const PersonalizedStatusBanner(
            icon: Icons.lock_outline_rounded,
            message:
                'Your import and review progress stay on this device until you choose to finalize the transfer.',
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Step $number. $title. $description',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 17, 12, 17),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(icon, color: colors.onPrimaryContainer, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
