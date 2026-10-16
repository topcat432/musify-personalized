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

/// The app's single spacing scale.
///
/// Every new or touched layout should reach for one of these values (or the
/// semantic aliases below) instead of an ad hoc `EdgeInsets`/`SizedBox`
/// literal. This does not replace the small set of existing outer-layer
/// constants in `lib/constants/app_constants.dart`
/// (`commonSingleChildScrollViewPadding`, `commonBarContentPadding`,
/// `commonListViewBottomPadding`, `miniPlayerTotalHeight`) — those remain the
/// outermost page-level layer described in `docs/VISUAL_OVERHAUL_PLAN.md`
/// §2.3. This scale is the general-purpose vocabulary everything else should
/// draw from, so the app does not accumulate a second, competing spacing
/// system.
abstract final class AppSpacing {
  /// 4dp. The smallest deliberate gap (e.g. icon-to-label baseline nudge).
  static const double xs = 4;

  /// 8dp. Compact gaps between closely related elements.
  static const double sm = 8;

  /// 12dp. The default gap between related controls/rows.
  static const double md = 12;

  /// 16dp. Standard page padding and moderate separation.
  static const double lg = 16;

  /// 20dp. Slightly generous padding for hero/emphasis surfaces.
  static const double xl = 20;

  /// 24dp. Separation between distinct sections.
  static const double xxl = 24;

  /// 32dp. Large structural spacing between major page regions.
  static const double xxxl = 32;

  /// Compact gap between tightly related elements (e.g. icon + label).
  static const double compactGap = sm;

  /// Normal gap between related controls, rows, or list items.
  static const double normalGap = md;

  /// Gap between distinct sections within a screen.
  static const double sectionGap = xxl;

  /// Default horizontal page padding for new/touched screens.
  static const double pagePadding = lg;

  /// Large structural spacing separating major page regions.
  static const double largeStructuralGap = xxxl;
}
