import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
