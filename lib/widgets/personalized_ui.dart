/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/material.dart';

/// Shared visual language for the personalized import and review workflow.
///
/// These widgets deliberately inherit Musify's active color scheme so the
/// workflow remains at home in dynamic-color, light, dark, and pure-black
/// themes.
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
          borderRadius: BorderRadius.circular(compact ? 24 : 28),
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
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: compact ? 5 : 8),
              ],
              Text(
                title,
                style:
                    (compact
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                          letterSpacing: -0.5,
                        ),
              ),
              SizedBox(height: compact ? 7 : 10),
              Text(
                description,
                style:
                    (compact
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyLarge)
                        ?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.42,
                        ),
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
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 5),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
        borderRadius: BorderRadius.circular(18),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
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
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = disableAnimations
        ? Duration.zero
        : Duration(milliseconds: 360 + delay.inMilliseconds);
    final delayFraction = duration.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / duration.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(
        delayFraction.clamp(0, 0.8).toDouble(),
        1,
        curve: Curves.easeOutCubic,
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
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
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
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
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
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
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
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
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
    return PersonalizedSurface(
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
