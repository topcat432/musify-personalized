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

/// Named typography roles layered on top of the active [TextTheme].
///
/// `docs/VISUAL_SYSTEM.md` already documents which [TextTheme] slot and
/// weight/spacing treatment each personalized moment should use (heroes,
/// section headings, eyebrows, metrics, supporting body copy). This
/// extension gives those documented treatments a name and a single
/// definition, instead of leaving every widget to repeat the same
/// `copyWith(fontWeight: ..., letterSpacing: ...)` literal. Every role still
/// resolves through [TextTheme] first, so text scaling, locale-driven font
/// fallback, and the app's active color scheme keep working exactly as
/// before.
///
/// Two roles — [metadata] and [numeric] — are new: they did not have a
/// dedicated name before this phase. `metadata` is for small supporting
/// labels (timestamps, counts-of-counts, secondary captions). `numeric` is
/// for prominent numeric values that benefit from tabular figures so digits
/// do not shift width as they change (e.g. animated counters).
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.heroTitle,
    required this.heroTitleCompact,
    required this.sectionTitle,
    required this.strongTitle,
    required this.body,
    required this.bodyCompact,
    required this.supportingBody,
    required this.eyebrow,
    required this.label,
    required this.metricValue,
    required this.metadata,
    required this.numeric,
  });

  factory AppTypography.fromTheme(TextTheme textTheme, ColorScheme colors) {
    return AppTypography(
      display: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: colors.onSurface,
      ),
      heroTitle: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -0.5,
        color: colors.onSurface,
      ),
      heroTitleCompact: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -0.5,
        color: colors.onSurface,
      ),
      sectionTitle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: colors.onSurface,
      ),
      strongTitle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: colors.onSurface,
      ),
      body: textTheme.bodyLarge?.copyWith(
        height: 1.42,
        color: colors.onSurfaceVariant,
      ),
      bodyCompact: textTheme.bodyMedium?.copyWith(
        height: 1.42,
        color: colors.onSurfaceVariant,
      ),
      supportingBody: textTheme.bodyMedium?.copyWith(
        height: 1.4,
        color: colors.onSurfaceVariant,
      ),
      eyebrow: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: colors.primary,
      ),
      label: textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
      metricValue: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: colors.onSurface,
      ),
      metadata: textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
      numeric: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: colors.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// Large, rare display moments (reserved for future use beyond this
  /// phase's shared primitives; verified available via tests).
  final TextStyle? display;

  /// Hero title, standard layout. Matches `PersonalizedHero`'s existing
  /// non-compact title treatment (`headlineSmall`, weight 800).
  final TextStyle? heroTitle;

  /// Hero title, compact layout. Matches `PersonalizedHero`'s existing
  /// compact title treatment (`titleLarge`, weight 800).
  final TextStyle? heroTitleCompact;

  /// Section heading title. Matches `PersonalizedSectionHeading`'s existing
  /// treatment (`titleLarge`, weight 700).
  final TextStyle? sectionTitle;

  /// Strong/emphasized title for dialogs and empty states (`titleLarge`,
  /// weight 800).
  final TextStyle? strongTitle;

  /// Hero description body copy (`bodyLarge`, relaxed line height).
  final TextStyle? body;

  /// Hero description body copy, compact layout (`bodyMedium`, relaxed line
  /// height).
  final TextStyle? bodyCompact;

  /// General supporting/description body copy (`bodyMedium`).
  final TextStyle? supportingBody;

  /// Uppercase eyebrow labels (`labelMedium`, weight 800, positive
  /// tracking, primary color).
  final TextStyle? eyebrow;

  /// Secondary labels (`labelMedium`, `onSurfaceVariant`).
  final TextStyle? label;

  /// Prominent metric values (`titleLarge`, weight 800, tight tracking).
  final TextStyle? metricValue;

  /// New role: small supporting metadata (timestamps, secondary captions).
  final TextStyle? metadata;

  /// New role: prominent numeric values with tabular figures so digit width
  /// stays stable as the value changes.
  final TextStyle? numeric;

  /// Resolves the typography roles for [context], falling back to deriving
  /// them from the active theme if the extension was not registered
  /// (defensive fallback; `getAppTheme` always registers it).
  static AppTypography of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppTypography>() ??
        AppTypography.fromTheme(theme.textTheme, theme.colorScheme);
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? heroTitle,
    TextStyle? heroTitleCompact,
    TextStyle? sectionTitle,
    TextStyle? strongTitle,
    TextStyle? body,
    TextStyle? bodyCompact,
    TextStyle? supportingBody,
    TextStyle? eyebrow,
    TextStyle? label,
    TextStyle? metricValue,
    TextStyle? metadata,
    TextStyle? numeric,
  }) {
    return AppTypography(
      display: display ?? this.display,
      heroTitle: heroTitle ?? this.heroTitle,
      heroTitleCompact: heroTitleCompact ?? this.heroTitleCompact,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      strongTitle: strongTitle ?? this.strongTitle,
      body: body ?? this.body,
      bodyCompact: bodyCompact ?? this.bodyCompact,
      supportingBody: supportingBody ?? this.supportingBody,
      eyebrow: eyebrow ?? this.eyebrow,
      label: label ?? this.label,
      metricValue: metricValue ?? this.metricValue,
      metadata: metadata ?? this.metadata,
      numeric: numeric ?? this.numeric,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t),
      heroTitle: TextStyle.lerp(heroTitle, other.heroTitle, t),
      heroTitleCompact: TextStyle.lerp(
        heroTitleCompact,
        other.heroTitleCompact,
        t,
      ),
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t),
      strongTitle: TextStyle.lerp(strongTitle, other.strongTitle, t),
      body: TextStyle.lerp(body, other.body, t),
      bodyCompact: TextStyle.lerp(bodyCompact, other.bodyCompact, t),
      supportingBody: TextStyle.lerp(supportingBody, other.supportingBody, t),
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t),
      label: TextStyle.lerp(label, other.label, t),
      metricValue: TextStyle.lerp(metricValue, other.metricValue, t),
      metadata: TextStyle.lerp(metadata, other.metadata, t),
      numeric: TextStyle.lerp(numeric, other.numeric, t),
    );
  }
}
