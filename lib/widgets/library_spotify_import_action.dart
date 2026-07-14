/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

class LibrarySpotifyImportAction extends StatelessWidget {
  const LibrarySpotifyImportAction({required this.onPressed, super.key});

  static const Key compactKey = ValueKey<String>('spotify-import-compact');
  static const Key labeledKey = ValueKey<String>('spotify-import-labeled');
  static const double labeledBreakpoint = 480;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.sizeOf(context).width >= labeledBreakpoint;
    const tooltip = 'Import and match Spotify tracks';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showLabel
          ? Padding(
              key: labeledKey,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: const Icon(FluentIcons.arrow_upload_24_regular),
                label: const Text('Spotify import'),
              ),
            )
          : IconButton(
              key: compactKey,
              onPressed: onPressed,
              icon: const Icon(FluentIcons.arrow_upload_24_regular),
              tooltip: tooltip,
            ),
    );
  }
}
