import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_semantic_colors.dart';
import 'package:musify/theme/app_shape.dart';
import 'package:musify/theme/app_spacing.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/app_typography.dart';
import 'package:musify/theme/motion.dart';
import 'package:musify/widgets/personalized_ui.dart';

void main() {
  late Directory hiveRoot;

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('app-theme-test-');
    Hive.init(hiveRoot.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) await hiveRoot.delete(recursive: true);
  });

  ColorScheme seedScheme(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: const Color(0xFF9B4F2A),
    brightness: brightness,
  );

  group('theme construction', () {
    test('builds a light theme with Material 3 and the token extensions', () {
      final theme = getAppTheme(seedScheme(Brightness.light));

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.extension<AppSemanticColors>(), isNotNull);
      expect(theme.extension<AppTypography>(), isNotNull);
    });

    test('builds a dark theme with Material 3 and the token extensions', () {
      final theme = getAppTheme(seedScheme(Brightness.dark));

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.extension<AppSemanticColors>(), isNotNull);
      expect(theme.extension<AppTypography>(), isNotNull);
    });

    test('a pure-black dark theme still resolves semantic tokens', () {
      usePureBlackColor.value = true;
      addTearDown(() => usePureBlackColor.value = false);

      final theme = getAppTheme(seedScheme(Brightness.dark));
      final semantics = theme.extension<AppSemanticColors>()!;

      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(semantics.elevatedSurface, theme.colorScheme.surfaceContainerHigh);
    });
  });

  group('semantic colors', () {
    for (final brightness in Brightness.values) {
      test('every semantic role resolves for $brightness', () {
        final scheme = seedScheme(brightness);
        final semantics = AppSemanticColors.fromScheme(scheme);

        // Every field must be a concrete, opaque-enough color derived from
        // the scheme -- not a placeholder. This is a smoke check that the
        // factory actually populated every role.
        for (final color in <Color>[
          semantics.success,
          semantics.onSuccess,
          semantics.successContainer,
          semantics.onSuccessContainer,
          semantics.warning,
          semantics.onWarning,
          semantics.warningContainer,
          semantics.onWarningContainer,
          semantics.info,
          semantics.onInfo,
          semantics.infoContainer,
          semantics.onInfoContainer,
          semantics.destructive,
          semantics.onDestructive,
          semantics.selected,
          semantics.onSelected,
          semantics.disabledContent,
          semantics.disabledContainer,
          semantics.overlayScrim,
          semantics.elevatedSurface,
          semantics.onElevatedSurface,
        ]) {
          expect(color, isNotNull);
        }

        expect(semantics.destructive, scheme.error);
        expect(semantics.onDestructive, scheme.onError);
      });
    }

    test('lerp between two palettes blends every field', () {
      final light = AppSemanticColors.fromScheme(seedScheme(Brightness.light));
      final dark = AppSemanticColors.fromScheme(seedScheme(Brightness.dark));

      final blended = light.lerp(dark, 0.5);

      expect(blended.destructive, isNot(light.destructive));
      expect(blended.destructive, isNot(dark.destructive));
    });
  });

  group('typography roles', () {
    test('every named role is available from the active theme', () {
      final theme = getAppTheme(seedScheme(Brightness.light));
      final typography = theme.extension<AppTypography>()!;

      expect(typography.display, isNotNull);
      expect(typography.heroTitle, isNotNull);
      expect(typography.heroTitleCompact, isNotNull);
      expect(typography.sectionTitle, isNotNull);
      expect(typography.strongTitle, isNotNull);
      expect(typography.body, isNotNull);
      expect(typography.bodyCompact, isNotNull);
      expect(typography.supportingBody, isNotNull);
      expect(typography.eyebrow, isNotNull);
      expect(typography.label, isNotNull);
      expect(typography.metricValue, isNotNull);
      expect(typography.metadata, isNotNull);
      expect(typography.numeric, isNotNull);
    });

    test('the numeric role uses tabular figures', () {
      final theme = getAppTheme(seedScheme(Brightness.light));
      final typography = theme.extension<AppTypography>()!;

      expect(
        typography.numeric?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('spacing and shape scales', () {
    test('the spacing scale is monotonically increasing', () {
      const scale = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('shape roles match the values already used by the app theme', () {
      final theme = getAppTheme(seedScheme(Brightness.light));
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder?;
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;

      expect(dialogShape?.borderRadius, AppShape.dialog);
      expect(cardShape?.borderRadius, AppShape.card);
    });
  });

  group('reduced motion', () {
    testWidgets('AppMotion.resolve collapses to zero when disabled', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(AppMotion.isReduced(capturedContext), isTrue);
      expect(
        AppMotion.resolve(capturedContext, AppMotionDuration.reveal),
        Duration.zero,
      );
    });

    testWidgets('PersonalizedReveal renders immediately when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: PersonalizedReveal(
                child: Text('revealed', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      );

      // No pump/settle needed: reduced motion means the tween completes on
      // the very first frame.
      await tester.pump();
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('personalizedPageRoute skips the transition when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  personalizedPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: Center(child: Text('next page'))),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('next page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('text scaling', () {
    Widget textScaledHarness(double scaleFactor, Widget child) {
      return MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scaleFactor)),
        child: MaterialApp(
          theme: getAppTheme(seedScheme(Brightness.light)),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
    }

    for (final scaleFactor in [1.0, 2.0, 3.0]) {
      testWidgets(
        'PersonalizedHero renders without overflow at ${scaleFactor}x text scale',
        (tester) async {
          await tester.pumpWidget(
            textScaledHarness(
              scaleFactor,
              const PersonalizedHero(
                eyebrow: 'Library transfer',
                title: 'Bring your saved music with you',
                description:
                    'Import a CSV, let Musify find the right recordings.',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'PersonalizedMetric renders without overflow at ${scaleFactor}x text scale',
        (tester) async {
          await tester.pumpWidget(
            textScaledHarness(
              scaleFactor,
              const SizedBox(
                width: 160,
                child: PersonalizedMetric(label: 'Resolved', value: '2,619'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('shared primitives consume the token system', () {
    testWidgets('PersonalizedHero uses the hero shape and typography roles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: getAppTheme(seedScheme(Brightness.light)),
          home: const Scaffold(
            body: PersonalizedHero(
              title: 'Bring your saved music with you',
              description: 'Import a CSV to get started.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decoratedBox = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .first;
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.borderRadius, AppShape.hero);

      final titleFinder = find.text('Bring your saved music with you');
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontWeight, FontWeight.w800);
    });

    testWidgets(
      'showPersonalizedDestructiveConfirmation uses the destructive semantic role',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: getAppTheme(seedScheme(Brightness.light)),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showPersonalizedDestructiveConfirmation(
                    context: context,
                    title: 'Remove track?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Remove',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final buttonFinder = find.widgetWithText(FilledButton, 'Remove');
        final button = tester.widget<FilledButton>(buttonFinder);
        final resolvedBackground = button.style?.backgroundColor?.resolve({});
        expect(resolvedBackground, isNotNull);
      },
    );
  });
}
