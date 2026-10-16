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

/// Semantic color aliases layered on top of the active [ColorScheme].
///
/// `docs/VISUAL_SYSTEM.md` already establishes which [ColorScheme] roles
/// mean success, warning, error, and neutral information (see
/// `PersonalizedStatusBanner`). This extension gives those meanings names so
/// new/touched widgets can ask for "the destructive color" or "the selected
/// color" instead of re-deriving the mapping (or reaching for a raw
/// `Colors.*` literal) at every call site.
///
/// Every field is derived from the active [ColorScheme], so light, dark,
/// pure-black, and dynamic-color themes all resolve correctly automatically —
/// nothing here introduces a fixed hex value.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.destructive,
    required this.onDestructive,
    required this.selected,
    required this.onSelected,
    required this.disabledContent,
    required this.disabledContainer,
    required this.overlayScrim,
    required this.elevatedSurface,
    required this.onElevatedSurface,
  });

  /// Derives the semantic palette from an active [ColorScheme]. Called once
  /// per theme construction in `getAppTheme`, so pure-black and dynamic-color
  /// overrides applied to the [ColorScheme] beforehand flow through
  /// automatically.
  factory AppSemanticColors.fromScheme(ColorScheme scheme) {
    return AppSemanticColors(
      success: scheme.primary,
      onSuccess: scheme.onPrimary,
      successContainer: scheme.primaryContainer,
      onSuccessContainer: scheme.onPrimaryContainer,
      warning: scheme.tertiary,
      onWarning: scheme.onTertiary,
      warningContainer: scheme.tertiaryContainer,
      onWarningContainer: scheme.onTertiaryContainer,
      info: scheme.onSurfaceVariant,
      onInfo: scheme.surfaceContainerHigh,
      infoContainer: scheme.surfaceContainerHigh,
      onInfoContainer: scheme.onSurfaceVariant,
      destructive: scheme.error,
      onDestructive: scheme.onError,
      selected: scheme.primaryContainer,
      onSelected: scheme.onPrimaryContainer,
      disabledContent: scheme.onSurface.withValues(alpha: 0.38),
      disabledContainer: scheme.onSurface.withValues(alpha: 0.12),
      overlayScrim: scheme.scrim,
      elevatedSurface: scheme.surfaceContainerHigh,
      onElevatedSurface: scheme.onSurface,
    );
  }

  /// Positive/progress emphasis. Mirrors `PersonalizedStatusBanner`'s
  /// success tone (`colorScheme.primary`/`primaryContainer`).
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Pending/attention emphasis. Mirrors the existing warning tone
  /// (`colorScheme.tertiary`/`tertiaryContainer`).
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Neutral information. Mirrors the existing neutral tone
  /// (`colorScheme.surfaceContainerHigh`/`onSurfaceVariant`).
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Destructive/irreversible actions. Mirrors `colorScheme.error`, already
  /// used by `showPersonalizedDestructiveConfirmation`.
  final Color destructive;
  final Color onDestructive;

  /// Selected/active state.
  final Color selected;
  final Color onSelected;

  /// Disabled content and disabled container fills, following the Material
  /// convention of 38%/12% opacity over `onSurface`.
  final Color disabledContent;
  final Color disabledContainer;

  /// Scrim for content drawn over album artwork or other imagery, replacing
  /// ad hoc `Colors.black`/`Colors.white` overlay literals with a themed
  /// value. Introduced for the token system; screens that still use raw
  /// overlay literals (e.g. the Review Sprint card) are migrated in a later,
  /// dedicated phase per `docs/VISUAL_OVERHAUL_PLAN.md` §10 Phase 8, not
  /// here.
  final Color overlayScrim;

  /// Elevated content surfaces above the base background.
  final Color elevatedSurface;
  final Color onElevatedSurface;

  /// Resolves the semantic palette for [context], falling back to deriving
  /// one from the active [ColorScheme] if the extension was not registered
  /// (defensive fallback; `getAppTheme` always registers it).
  static AppSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fromScheme(theme.colorScheme);
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? destructive,
    Color? onDestructive,
    Color? selected,
    Color? onSelected,
    Color? disabledContent,
    Color? disabledContainer,
    Color? overlayScrim,
    Color? elevatedSurface,
    Color? onElevatedSurface,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      destructive: destructive ?? this.destructive,
      onDestructive: onDestructive ?? this.onDestructive,
      selected: selected ?? this.selected,
      onSelected: onSelected ?? this.onSelected,
      disabledContent: disabledContent ?? this.disabledContent,
      disabledContainer: disabledContainer ?? this.disabledContainer,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      onElevatedSurface: onElevatedSurface ?? this.onElevatedSurface,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      onSelected: Color.lerp(onSelected, other.onSelected, t)!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
      disabledContainer: Color.lerp(
        disabledContainer,
        other.disabledContainer,
        t,
      )!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      onElevatedSurface: Color.lerp(
        onElevatedSurface,
        other.onElevatedSurface,
        t,
      )!,
    );
  }
}
