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

/// Named motion durations.
///
/// These are not new values — they extract the vocabulary
/// `docs/VISUAL_SYSTEM.md` already documents and that
/// `lib/widgets/personalized_ui.dart` already implements ad hoc
/// (220/240/320/240/360 ms). Naming them here lets new/touched widgets share
/// one vocabulary instead of repeating literal millisecond counts.
abstract final class AppMotionDuration {
  /// 120ms. Immediate, low-ceremony feedback (press states, small toggles).
  static const Duration fastFeedback = Duration(milliseconds: 120);

  /// 220ms. Normal in-place surface/state transitions.
  static const Duration normalTransition = Duration(milliseconds: 220);

  /// 240ms. Value/metric changes (fade + scale).
  static const Duration metricChange = Duration(milliseconds: 240);

  /// 320ms. Emphasized entrance transitions (page/route entry).
  static const Duration emphasizedEnter = Duration(milliseconds: 320);

  /// 240ms. Emphasized exit transitions (page/route exit).
  static const Duration emphasizedExit = Duration(milliseconds: 240);

  /// 240ms. Dismissal/commit-or-recover timing (e.g. review-deck actions).
  static const Duration dismissal = Duration(milliseconds: 240);

  /// 360ms. Base duration for staggered reveal entrances, before any
  /// per-item delay is added.
  static const Duration reveal = Duration(milliseconds: 360);
}

/// Named motion curves shared by personalized surfaces and transitions.
abstract final class AppMotionCurve {
  static const Curve standardEnter = Curves.easeOutCubic;
  static const Curve standardExit = Curves.easeInCubic;
}

/// Reduced-motion helpers.
///
/// Every new animation must consult [AppMotion.isReduced] (or
/// [AppMotion.resolve]) so it collapses to no motion when the platform
/// requests reduced motion, matching the existing convention already used by
/// `PersonalizedReveal` and `personalizedPageRoute`.
abstract final class AppMotion {
  /// Whether the current context has requested reduced/disabled animations.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Returns [duration] unchanged, or [Duration.zero] when the current
  /// context has requested reduced motion.
  static Duration resolve(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}
