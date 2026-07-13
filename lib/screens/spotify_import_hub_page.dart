/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';

class SpotifyImportHubPage extends StatelessWidget {
  const SpotifyImportHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spotify import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _WorkflowCard(
            icon: Icons.upload_file,
            title: 'Import or replace CSV',
            description:
                'Select a Spotify, Exportify, Soundiiz, or compatible music CSV and save its normalized track records locally.',
            buttonLabel: 'Open CSV importer',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SpotifyImportPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _WorkflowCard(
            icon: Icons.manage_search,
            title: 'Match saved tracks',
            description:
                'Resume the saved import and identify safe individual-song sources without letting compilations or long videos into the library.',
            buttonLabel: 'Open track matcher',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SpotifyMatchingPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _WorkflowCard(
            icon: Icons.swipe_rounded,
            title: 'Quick review',
            description:
                'Review one unresolved song at a time. Hear the suggested source, then swipe or tap Accept, None, or Later.',
            buttonLabel: 'Start quick review',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SpotifyReviewSprintPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
