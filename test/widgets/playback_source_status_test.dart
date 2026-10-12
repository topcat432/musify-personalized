import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/models/playback_source_info.dart';
import 'package:musify/widgets/playback_source_status.dart';

void main() {
  for (final locale in ['en', 'es']) {
    testWidgets('source details remain truthful and usable in $locale', (
      tester,
    ) async {
      final stream = StreamController<PlaybackSourceInfo?>();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(child: PlaybackSourceStatus(stream: stream.stream)),
                ],
              ),
            ),
          ),
        ),
      );
      stream.add(
        const PlaybackSourceInfo(
          PlaybackSourceKind.youtube,
          container: 'MP4',
          includesVideo: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('YouTube · MP4'), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Spotify'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      stream.add(const PlaybackSourceInfo(PlaybackSourceKind.local));
      await tester.pumpAndSettle();
      expect(find.textContaining('YouTube'), findsNothing);
      stream.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(stream.close());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    });
  }
}
