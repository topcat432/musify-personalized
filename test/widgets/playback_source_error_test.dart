import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/playback_source_error.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('source error stays actionable at width $width scale $scale', (
        tester,
      ) async {
        final state = StreamController<PlaybackState>();
        var opens = 0;
        await tester.binding.setSurfaceSize(Size(width, 600));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 600),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: PlaybackSourceError(
                  stream: state.stream,
                  onOpenLibrary: () => opens++,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Library'), findsNothing);
        state.add(
          PlaybackState(
            errorMessage:
                'Source unavailable. Choose another recording or a local track.',
          ),
        );
        await tester.pump();
        expect(find.textContaining('Choose another recording'), findsOneWidget);
        await tester.tap(find.text('Library'));
        expect(opens, 1);
        expect(tester.takeException(), isNull);
        state.add(PlaybackState());
        await tester.pump();
        expect(find.text('Library'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        unawaited(state.close());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
