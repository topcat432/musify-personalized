import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/widgets/position_slider.dart';

void main() {
  testWidgets(
    'zero seek and new-track duration replace the preceding position',
    (tester) async {
      final positions = StreamController<PositionData>(sync: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PositionSlider(positionStream: positions.stream),
          ),
        ),
      );
      positions.add(
        PositionData(Duration.zero, Duration.zero, const Duration(seconds: 45)),
      );
      await tester.pump();
      expect(find.text('00:45'), findsOneWidget);
      positions.add(
        PositionData(
          const Duration(seconds: 9),
          Duration.zero,
          const Duration(seconds: 45),
        ),
      );
      await tester.pump();
      expect(find.text('00:09'), findsOneWidget);
      positions.add(
        PositionData(Duration.zero, Duration.zero, const Duration(seconds: 45)),
      );
      await tester.pump();
      expect(find.text('00:09'), findsNothing);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      positions.add(
        PositionData(Duration.zero, Duration.zero, const Duration(seconds: 90)),
      );
      await tester.pump();
      expect(find.text('00:45'), findsNothing);
      expect(find.text('01:30'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(positions.close());
      await tester.pump();
    },
  );
}
