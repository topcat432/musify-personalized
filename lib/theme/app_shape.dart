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

/// The app's named shape/radius roles.
///
/// Every value here matches a radius already in active use (theme-level
/// `cardTheme`/`dialogTheme`/`inputDecorationTheme`/`popupMenuTheme` in
/// `lib/theme/app_themes.dart`, and the personalized surfaces documented in
/// `docs/VISUAL_SYSTEM.md`). Formalizing them as named roles lets new/touched
/// widgets reuse a deliberate value instead of inventing another stray
/// radius, and gives a single place to retire an accidental one-off later.
abstract final class AppShape {
  /// 12dp. Inputs, buttons, chips, popups, and snackbars.
  static const double controlRadius = 12;

  /// 16dp. Cards and other primary content containers.
  static const double cardRadius = 16;

  /// 8dp. Small artwork thumbnails (matches `commonMiniArtworkRadius`).
  static const double artworkRadius = 8;

  /// 18dp. Inline status/feedback banners.
  static const double statusRadius = 18;

  /// 24dp. Grouped personalized surfaces (`PersonalizedSurface`).
  static const double surfaceRadius = 24;

  /// 24dp. Compact-mode hero surfaces.
  static const double heroRadiusCompact = 24;

  /// 28dp. Standard hero surfaces, dialogs, and sheets.
  static const double heroRadius = 28;

  /// 28dp. Dialogs and modal bottom sheets (matches `dialogTheme`).
  static const double dialogRadius = 28;

  /// 12dp. Popup menus and snackbars.
  static const double popupRadius = 12;

  /// Fully rounded pills/chips.
  static const double pillRadius = 999;

  static BorderRadius get control => BorderRadius.circular(controlRadius);
  static BorderRadius get card => BorderRadius.circular(cardRadius);
  static BorderRadius get artwork => BorderRadius.circular(artworkRadius);
  static BorderRadius get status => BorderRadius.circular(statusRadius);
  static BorderRadius get surface => BorderRadius.circular(surfaceRadius);
  static BorderRadius get heroCompact =>
      BorderRadius.circular(heroRadiusCompact);
  static BorderRadius get hero => BorderRadius.circular(heroRadius);
  static BorderRadius get dialog => BorderRadius.circular(dialogRadius);
  static BorderRadius get popup => BorderRadius.circular(popupRadius);
  static const BorderRadius pill = BorderRadius.all(
    Radius.circular(pillRadius),
  );
}
