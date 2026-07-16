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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/theme/app_spacing.dart';
import 'package:musify/theme/app_typography.dart';
import 'package:musify/widgets/personalized_ui.dart';

class OfflineSearchPlaceholder extends StatelessWidget {
  const OfflineSearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: Center(
        child: PersonalizedReveal(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.cloud_off_24_regular,
                size: 64,
                // `AppSemanticColors.disabledContent` is documented for
                // actually-disabled controls, not decorative empty-state
                // iconography — use the plain muted-icon Material role
                // instead (matches the pre-token 0.5-alpha-over-onSurface
                // look this replaced).
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                // This reuses the generic `error` string rather than an
                // offline-specific message — a known, tracked copy defect
                // (see the Phase 3 PR notes), deliberately left unchanged
                // in this visual-only pass.
                context.l10n!.error,
                textAlign: TextAlign.center,
                style: typography.supportingBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
