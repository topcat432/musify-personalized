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
}
