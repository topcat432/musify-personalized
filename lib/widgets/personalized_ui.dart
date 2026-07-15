/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:musify/theme/app_semantic_colors.dart';
import 'package:musify/theme/app_shape.dart';
import 'package:musify/theme/app_spacing.dart';
import 'package:musify/theme/app_typography.dart';
import 'package:musify/theme/motion.dart';

/// Shared visual language for the personalized import and review workflow.
///
/// These widgets deliberately inherit Musify's active color scheme so the
/// workflow remains at home in dynamic-color, light, dark, and pure-black
/// themes.
///
/// This file consumes the foundation tokens in `lib/theme/` (spacing, shape,
/// motion, typography, semantic colors) established in
/// `docs/VISUAL_OVERHAUL_PLAN.md` Phase 1. Every token substitution below
/// preserves the exact numeric value already in use — this phase formalizes
/// the existing design language, it does not redesign it. A few
/// fine-tuned, non-scale values (e.g. the hero's own compact/standard
/// padding rhythm) are deliberately left as local literals rather than
/// forced onto the general scale, since changing them would be a visual
/// change, not a token substitution.
class PersonalizedHero extends StatelessWidget {
  const PersonalizedHero({
    required this.title,
    required this.description,
    super.key,
    this.eyebrow,
    this.icon,
    this.footer,
    this.compact = false,
  });

  final String? eyebrow;
  final String title;
  final String description;
  final IconData? icon;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typography = AppTypography.of(context);

    return PersonalizedReveal(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer.withValues(alpha: 0.72),
              colors.surfaceContainerHigh,
            ],
          ),
          borderRadius: compact ? AppShape.heroCompact : AppShape.hero,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 18 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                _HeroIcon(icon: icon!, compact: compact),
                SizedBox(height: compact ? 14 : 20),
              ],
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: typography.eyebrow),
                SizedBox(height: compact ? 5 : 8),
              ],
              Text(
                title,
                style: compact
                    ? typography.heroTitleCompact
                    : typography.heroTitle,
              ),
              SizedBox(height: compact ? 7 : 10),
              Text(
                description,
                style: compact ? typography.bodyCompact : typography.body,
              ),
              if (footer != null) ...[
                SizedBox(height: compact ? 14 : 18),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.compact});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox.square(
        dimension: compact ? 42 : 48,
        child: Icon(icon, color: colors.primary, size: compact ? 23 : 26),
      ),
    );
  }
}

class PersonalizedSurface extends StatelessWidget {
  const PersonalizedSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderRadius = AppShape.surfaceRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotionDuration.normalTransition),
      curve: AppMotionCurve.standardEnter,
      decoration: BoxDecoration(
        color: color ?? colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PersonalizedSectionHeading extends StatelessWidget {
  const PersonalizedSectionHeading({
    required this.title,
    super.key,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: typography.sectionTitle),
              if (description != null) ...[
                const SizedBox(height: 5),
                Text(description!, style: typography.supportingBody),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.normalGap),
          trailing!,
        ],
      ],
    );
  }
}

enum PersonalizedStatusTone { neutral, success, warning, error }

class PersonalizedStatusBanner extends StatelessWidget {
  const PersonalizedStatusBanner({
    required this.message,
    super.key,
    this.title,
    this.icon,
    this.tone = PersonalizedStatusTone.neutral,
    this.trailing,
  });

  final String? title;
  final String message;
  final IconData? icon;
  final PersonalizedStatusTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground, defaultIcon) = switch (tone) {
      PersonalizedStatusTone.neutral => (
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
      PersonalizedStatusTone.success => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_outline_rounded,
      ),
      PersonalizedStatusTone.warning => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        Icons.schedule_rounded,
      ),
      PersonalizedStatusTone.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline_rounded,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.82),
        borderRadius: AppShape.status,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: foreground, size: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class PersonalizedMetric extends StatelessWidget {
  const PersonalizedMetric({
    required this.label,
    required this.value,
    super.key,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = AppTypography.of(context);
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: colors.primary),
            const SizedBox(height: 10),
          ],
          AnimatedSwitcher(
            duration: AppMotion.resolve(
              context,
              AppMotionDuration.metricChange,
            ),
            switchInCurve: AppMotionCurve.standardEnter,
            switchOutCurve: AppMotionCurve.standardExit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.metricValue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.label,
          ),
        ],
      ),
    );
  }
}

class PersonalizedReveal extends StatelessWidget {
  const PersonalizedReveal({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.resolve(
      context,
      AppMotionDuration.reveal + delay,
    );
    final delayFraction = duration.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / duration.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(
        delayFraction.clamp(0, 0.8).toDouble(),
        1,
        curve: AppMotionCurve.standardEnter,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            offset.dx * 240 * (1 - value),
            offset.dy * 240 * (1 - value),
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

Route<T> personalizedPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotionDuration.emphasizedEnter,
    reverseTransitionDuration: AppMotionDuration.emphasizedExit,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.isReduced(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotionCurve.standardEnter,
        reverseCurve: AppMotionCurve.standardExit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.035, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<bool> showPersonalizedDestructiveConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      final semanticColors = AppSemanticColors.of(sheetContext);
      final typography = AppTypography.of(sheetContext);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 52,
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.strongTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: typography.supportingBody,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('Keep track'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: semanticColors.destructive,
                      foregroundColor: semanticColors.onDestructive,
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

class PersonalizedEmptyState extends StatelessWidget {
  const PersonalizedEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typography = AppTypography.of(context);
    return PersonalizedSurface(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 54,
              child: Icon(icon, color: colors.onPrimaryContainer, size: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            // Deliberately not `typography.sectionTitle`: that role also
            // applies a -0.25 letter-spacing tweak this empty-state title
            // has never had. Keeping the literal here avoids a token
            // substitution that would silently change rendered spacing.
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: typography.supportingBody,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
