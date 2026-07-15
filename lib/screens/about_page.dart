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
import 'package:musify/constants/app_constants.dart';
import 'package:musify/constants/version.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/theme/app_shape.dart';
import 'package:musify/theme/app_spacing.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/personalized_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.about)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            PersonalizedReveal(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The brand wordmark deliberately keeps its own
                    // `paytoneOne` treatment (matching the app bar's brand
                    // typography, per `docs/VISUAL_SYSTEM.md`) rather than an
                    // `AppTypography` role, since none of the shared roles
                    // model this one-off wordmark size.
                    Text(
                      'Musify',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'paytoneOne',
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: AppShape.pill,
                      ),
                      child: Text(
                        'v$appVersion',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            PersonalizedReveal(
              delay: const Duration(milliseconds: 80),
              child: PersonalizedSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md + 2,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppShape.control,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.network(
                          'https://avatars.githubusercontent.com/u/79704324?v=4',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          // A static placeholder, not a spinner: an
                          // indeterminate `CircularProgressIndicator` here
                          // would tick forever, which is fine on a real
                          // device but makes `pumpAndSettle` hang in any
                          // widget test that renders this screen mid-load.
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return ColoredBox(
                              color: colorScheme.surfaceContainerHigh,
                              child: Icon(
                                FluentIcons.person_24_regular,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                size: 24,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                                color: colorScheme.surfaceContainerHigh,
                                child: Icon(
                                  FluentIcons.person_24_filled,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valeri Gokadze',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'WEB & APP Developer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SocialButton(
                          icon: FluentIcons.code_24_filled,
                          tooltip: 'Github',
                          semanticLabel: 'Open the GitHub profile',
                          onPressed: () {
                            launchURL(Uri.parse('https://github.com/gokadzev'));
                          },
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _SocialButton(
                          icon: FluentIcons.globe_24_filled,
                          tooltip: 'Website',
                          semanticLabel: 'Open the developer website',
                          onPressed: () {
                            launchURL(Uri.parse('https://gokadzev.github.io'));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: AppShape.control,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppShape.control,
          child: ExcludeSemantics(
            child: Tooltip(
              message: tooltip,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
