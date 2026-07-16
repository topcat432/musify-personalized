import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/marquee.dart';

void main() {
  // Mirrors real consumers (section_title.dart, mini_player.dart,
  // marquee_text_widget.dart): they all pass a Text directly as the
  // MarqueeWidget child and rely on an ambient width constraint from the
  // surrounding layout, not an inner SizedBox around the Text itself.
  Widget buildMarqueeTree(
    String label, {
    bool reducedMotion = false,
    Duration animationDuration = const Duration(milliseconds: 80),
    Duration pauseDuration = Duration.zero,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(200, 48),
          disableAnimations: reducedMotion,
        ),
        child: Scaffold(
          body: SizedBox(
            width: 120,
            height: 48,
            child: MarqueeWidget(
              animationDuration: animationDuration,
              backDuration: const Duration(milliseconds: 40),
              pauseDuration: pauseDuration,
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }

  const shortLabel = 'Short';
  const longLabelA = 'A much longer marquee label that should overflow';
  const longLabelB = 'A different, equally long overflowing marquee label';

  Future<void> pumpMarquee(
    WidgetTester tester,
    String label, {
    bool reducedMotion = false,
    Duration animationDuration = const Duration(milliseconds: 80),
    Duration pauseDuration = Duration.zero,
  }) async {
    await tester.pumpWidget(
      buildMarqueeTree(
        label,
        reducedMotion: reducedMotion,
        animationDuration: animationDuration,
        pauseDuration: pauseDuration,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ScrollController controllerOf(WidgetTester tester) {
    return tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
  }

  testWidgets('settles without polling when content fits initially', (
    tester,
  ) async {
    await pumpMarquee(tester, shortLabel);

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts scrolling when overflowing content is rebuilt in', (
    tester,
  ) async {
    await pumpMarquee(tester, shortLabel);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(buildMarqueeTree(longLabelA));
    await tester.pump();
    await tester.pump();

    final controller = controllerOf(tester);
    expect(controller.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(0));

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (controller.offset > 0) break;
    }
    expect(controller.offset, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets(
    'does not reset scroll position for an equivalent rebuilt child instance',
    (tester) async {
      await pumpMarquee(tester, longLabelA);

      final controller = controllerOf(tester);
      expect(controller.position.maxScrollExtent, greaterThan(0));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (controller.offset > 0) break;
      }
      expect(controller.offset, greaterThan(0));

      // Rebuild with a brand-new Text instance carrying the exact same
      // logical content, mirroring a parent (e.g. the mini player)
      // rebuilding on every playback-state tick. A single, zero-duration
      // pump exposes a synchronous reset immediately, before any further
      // animation progress could mask it.
      await tester.pumpWidget(buildMarqueeTree(longLabelA));
      await tester.pump();

      expect(controller.offset, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'resets scroll position when overflowing content genuinely changes '
    '(e.g. a track change)',
    (tester) async {
      await pumpMarquee(tester, longLabelA);

      final controller = controllerOf(tester);
      expect(controller.position.maxScrollExtent, greaterThan(0));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (controller.offset > 0) break;
      }
      expect(controller.offset, greaterThan(0));

      // A different, still-overflowing title (e.g. the Now Playing screen's
      // unkeyed track change, since NowPlayingControls/MarqueeTextWidget are
      // built with no key) is a genuine content change and must reset,
      // unlike an equivalent rebuild of the same logical text above.
      await tester.pumpWidget(buildMarqueeTree(longLabelB));
      await tester.pump();

      expect(controller.offset, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'normalizes scroll position when overflowing content shrinks to fit',
    (tester) async {
      await pumpMarquee(tester, longLabelA);

      final controller = controllerOf(tester);
      expect(controller.position.maxScrollExtent, greaterThan(0));

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (controller.offset > 0) break;
      }
      expect(controller.offset, greaterThan(0));

      // Rebuild with content short enough to fit; the overflow that
      // justified the current scroll offset no longer exists.
      await tester.pumpWidget(buildMarqueeTree(shortLabel));
      await tester.pump();
      await tester.pump();

      expect(controller.position.maxScrollExtent, 0);
      expect(controller.offset, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets('does not animate when reduced motion is enabled', (
    tester,
  ) async {
    await pumpMarquee(tester, longLabelA, reducedMotion: true);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    final controller = controllerOf(tester);
    expect(controller.offset, 0);
  });
}
