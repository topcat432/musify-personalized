import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/marquee.dart';

void main() {
  Future<void> pumpMarquee(
    WidgetTester tester, {
    required Widget child,
    bool reducedMotion = false,
    Duration animationDuration = const Duration(milliseconds: 80),
    Duration pauseDuration = Duration.zero,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
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
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('settles without polling when content fits initially', (
    tester,
  ) async {
    await pumpMarquee(
      tester,
      child: const Text('Short', maxLines: 1, softWrap: false),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts scrolling when overflowing content is rebuilt in', (
    tester,
  ) async {
    Widget marqueeChild(String label) {
      return SizedBox(
        width: 320,
        child: Text(label, maxLines: 1, softWrap: false),
      );
    }

    await pumpMarquee(
      tester,
      child: const SizedBox(
        width: 80,
        child: Text('Short', maxLines: 1, softWrap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(200, 48)),
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 48,
              child: MarqueeWidget(
                animationDuration: const Duration(milliseconds: 80),
                backDuration: const Duration(milliseconds: 40),
                pauseDuration: Duration.zero,
                child: marqueeChild(
                  'A much longer marquee label that should overflow',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
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

  testWidgets('does not animate when reduced motion is enabled', (
    tester,
  ) async {
    await pumpMarquee(
      tester,
      reducedMotion: true,
      child: SizedBox(
        width: 320,
        child: const Text(
          'A much longer marquee label that should overflow',
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(controller.offset, 0);
  });
}
