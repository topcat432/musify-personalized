import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/library_spotify_import_action.dart';

void main() {
  Future<void> pumpAction(
    WidgetTester tester, {
    required double width,
    required VoidCallback onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(
            appBar: AppBar(
              actions: [
                LibrarySpotifyImportAction(onPressed: onPressed),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses a compact non-overlay action on phone widths', (
    tester,
  ) async {
    var pressed = false;
    await pumpAction(
      tester,
      width: 360,
      onPressed: () => pressed = true,
    );

    expect(find.byKey(LibrarySpotifyImportAction.compactKey), findsOneWidget);
    expect(find.byKey(LibrarySpotifyImportAction.labeledKey), findsNothing);
    await tester.tap(find.byKey(LibrarySpotifyImportAction.compactKey));
    expect(pressed, isTrue);
  });

  testWidgets('shows the labeled library action when space allows', (
    tester,
  ) async {
    await pumpAction(tester, width: 720, onPressed: () {});

    expect(find.byKey(LibrarySpotifyImportAction.labeledKey), findsOneWidget);
    expect(find.text('Spotify import'), findsOneWidget);
    expect(find.byKey(LibrarySpotifyImportAction.compactKey), findsNothing);
  });
}
