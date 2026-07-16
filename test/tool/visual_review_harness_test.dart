import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/theme/app_semantic_colors.dart';
import 'package:musify/theme/app_typography.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  testWidgets('scrollToText brings offscreen text into the viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...List<Widget>.generate(
                  30,
                  (index) => SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Row $index'),
                    ),
                  ),
                ),
                const Text('Data safety'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data safety'), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await scrollToText(tester, 'Data safety');

    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('scrollToText fails clearly when text is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Visible only'))),
    );
    await tester.pumpAndSettle();

    await expectLater(
      scrollToText(tester, 'Data safety'),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('pumpPriorityGolden fails near the requested settle timeout, not '
      "pumpAndSettle's much longer default", (tester) async {
    // A repeating controller keeps scheduling frames forever, simulating a
    // ticker/image/marquee left running during a golden pump.
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 50),
    )..repeat();
    addTearDown(controller.dispose);

    final start = tester.binding.clock.now();
    Object? caught;
    try {
      await pumpPriorityGolden(
        tester,
        widget: MaterialApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                const Scaffold(body: SizedBox(width: 10, height: 10)),
          ),
        ),
        viewport: const Size(200, 200),
        settleTimeout: const Duration(milliseconds: 500),
      );
    } catch (e) {
      caught = e;
    } finally {
      controller.stop();
    }
    final elapsed = tester.binding.clock.now().difference(start);

    expect(caught, isA<FlutterError>());
    expect(
      (caught! as FlutterError).message,
      contains('pumpAndSettle timed out'),
    );
    // Comfortably above the requested timeout, but nowhere near
    // pumpAndSettle's 10-minute default: proves settleTimeout was honored
    // as the timeout rather than treated as the per-pump duration.
    expect(elapsed, lessThan(const Duration(seconds: 5)));
  });

  group('productionReviewTheme applies the loaded font to every role', () {
    // `loadVisualReviewFonts` does real dart:io file reads; those never
    // complete inside a `testWidgets` body's fake-async zone unless run from
    // `setUpAll` (matching the convention `tool/visual_review_test.dart` and
    // `tool/visual_review_priority_test.dart` already use).
    setUpAll(loadVisualReviewFonts);

    // `getAppTheme` reads settings (e.g. `predictiveBack`, `usePureBlackColor`)
    // from the Hive `settings` box, so it must be open before calling
    // `productionReviewTheme`.
    late Directory hiveRoot;

    setUp(() async {
      hiveRoot = await Directory.systemTemp.createTemp(
        'visual-review-typography-',
      );
      Hive.init(hiveRoot.path);
      await Hive.openBox('settings');
    });

    tearDown(() async {
      await Hive.close();
      if (await hiveRoot.exists()) {
        await hiveRoot.delete(recursive: true);
      }
    });

    Future<BuildContext> pumpAndCaptureContext(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: productionReviewTheme(brightness),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      await tester.pump();
      return capturedContext;
    }

    testWidgets('Theme.of(context).textTheme uses the loaded font', (
      tester,
    ) async {
      final context = await pumpAndCaptureContext(tester, Brightness.light);
      final textTheme = Theme.of(context).textTheme;

      // Representative roles actually consumed across the app.
      expect(textTheme.bodyLarge?.fontFamily, 'visualSans');
      expect(textTheme.bodyMedium?.fontFamily, 'visualSans');
      expect(textTheme.titleLarge?.fontFamily, 'visualSans');
      expect(textTheme.labelMedium?.fontFamily, 'visualSans');
      expect(textTheme.labelSmall?.fontFamily, 'visualSans');
      expect(textTheme.displaySmall?.fontFamily, 'visualSans');
      expect(textTheme.headlineSmall?.fontFamily, 'visualSans');
    });

    testWidgets(
      'AppTypography.of(context) roles all use the loaded font, not the '
      'unloaded original',
      (tester) async {
        final context = await pumpAndCaptureContext(tester, Brightness.dark);
        final typography = AppTypography.of(context);

        // Every non-null role, so a newly added role cannot silently regress
        // back to the unloaded production font without failing this test.
        final roles = <String, TextStyle?>{
          'display': typography.display,
          'heroTitle': typography.heroTitle,
          'heroTitleCompact': typography.heroTitleCompact,
          'sectionTitle': typography.sectionTitle,
          'strongTitle': typography.strongTitle,
          'body': typography.body,
          'bodyCompact': typography.bodyCompact,
          'supportingBody': typography.supportingBody,
          'eyebrow': typography.eyebrow,
          'label': typography.label,
          'metricValue': typography.metricValue,
          'metadata': typography.metadata,
          'numeric': typography.numeric,
        };

        for (final entry in roles.entries) {
          expect(
            entry.value,
            isNotNull,
            reason: '${entry.key} should resolve from the theme text theme',
          );
          expect(
            entry.value!.fontFamily,
            'visualSans',
            reason:
                '${entry.key} still uses the unloaded font and would render '
                'as Ahem/tofu in a golden',
          );
        }
      },
    );

    testWidgets('existing semantic-color extension remains present', (
      tester,
    ) async {
      final context = await pumpAndCaptureContext(tester, Brightness.light);
      expect(Theme.of(context).extension<AppSemanticColors>(), isNotNull);
    });
  });
}
