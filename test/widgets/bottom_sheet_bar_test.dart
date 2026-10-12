import 'dart:ui' show SemanticsFlag;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';

void main() {
  testWidgets(
    'picker options expose their selected state and remain actionable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var highSelected = true;
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    BottomSheetBar('High', () {
                      taps++;
                      setState(() => highSelected = true);
                    }, highSelected),
                    BottomSheetBar('Low', () {
                      taps++;
                      setState(() => highSelected = false);
                    }, !highSelected),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(
          tester
              .getSemantics(find.text('High'))
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
        );
        expect(
          tester
              .getSemantics(find.text('Low'))
              .hasFlag(SemanticsFlag.isSelected),
          isFalse,
        );
        await tester.tap(find.text('Low'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(
          tester
              .getSemantics(find.text('Low'))
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
        );
        expect(
          tester
              .getSemantics(find.text('High'))
              .hasFlag(SemanticsFlag.isSelected),
          isFalse,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
}
