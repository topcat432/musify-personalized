import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/spotify_import_routing_state.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SpotifyImportDestinationSnapshot snapshot;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('destination-page-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    final songs = [
      for (var row = 1; row <= 3; row++)
        {'ytid': 'fixture-$row', 'title': 'Fixture $row'},
    ];
    await Hive.box('user').putAll({
      'spotifyImportMetadata': {
        'importSessionId': 'fixture-session',
        'fileName': 'fixture.csv',
      },
      'spotifyImportTracks': [
        for (var row = 1; row <= 3; row++) {'sourceRow': row},
      ],
      'spotifyMatchResults': [
        for (var row = 1; row <= 3; row++)
          {
            'sourceRow': row,
            'status': 'matched',
            'bestCandidate': songs[row - 1],
          },
      ],
    });
    snapshot = SpotifyImportDestinationSnapshot(
      importSessionId: 'fixture-session',
      sourceName: 'fixture',
      resolvedSongs: songs,
      resolvedResultCount: 3,
      unresolvedCount: 0,
      customPlaylists: const [],
    );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> openPage(WidgetTester tester) async {
    await tester.runAsync(() async {
      snapshot = await const SpotifyImportDestinationService().loadSnapshot();
    });
    await tester.pumpWidget(
      priorityReviewApp(
        child: SpotifyImportDestinationPage(initialSnapshot: snapshot),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text(label)),
      alignment: 0.35,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Review'));
    });
    await tester.pumpAndSettle();
  }

  Future<void> transfer(WidgetTester tester) async {
    final oldHistory =
        (Hive.box('user').get('spotifyImportMetadata')['routingHistory']
                    as List? ??
                [])
            .length;
    await tester.tap(find.text('Transfer songs'));
    await tester.pump();
    var completed = false;
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
      final history =
          Hive.box('user').get('spotifyImportMetadata')['routingHistory']
              as List? ??
          [];
      if (history.length == oldHistory + 1 &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.text('Review').evaluate().length == 1 &&
          find.byType(SpotifyImportConfirmationDialog).evaluate().isEmpty) {
        completed = true;
        break;
      }
    }
    expect(
      completed,
      isTrue,
      reason: 'Confirmed transfer must finish its durable audit',
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'individual selection previews source order, cancels and repeats safely',
    (tester) async {
      final rows = List<Map>.from(Hive.box('user').get('spotifyMatchResults'));
      rows[1] = Map.from(rows[1])
        ..['bestCandidate'] = {
          'ytid': 'chosen-alternative',
          'title': 'Selected alternative',
          'artist': 'Fixture artist',
        };
      await tester.runAsync(() async {
        await Hive.box(
          'user',
        ).put('spotifyMatchResults', [rows[2], rows[0], rows[1]]);
      });
      await openPage(tester);
      await choose(tester, 'Choose individual songs');
      for (final id in ['fixture-3', 'chosen-alternative']) {
        final tile = find.byKey(ValueKey('import-recording-$id'));
        await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      await review(tester);
      final dialog = tester.widget<SpotifyImportConfirmationDialog>(
        find.byType(SpotifyImportConfirmationDialog),
      );
      expect(dialog.preview.selectedSongs.map((song) => song['ytid']), [
        'chosen-alternative',
        'fixture-3',
      ]);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(userLikedSongsList.value, isEmpty);
      expect(
        Hive.box('user').get('spotifyImportMetadata')['routingHistory'],
        isNull,
      );
      await review(tester);
      await transfer(tester);
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'chosen-alternative',
        'fixture-3',
      ]);
      await review(tester);
      final repeated = tester.widget<SpotifyImportConfirmationDialog>(
        find.byType(SpotifyImportConfirmationDialog),
      );
      expect(repeated.preview.alreadyPresentCount, 2);
      expect(repeated.preview.newCount, 0);
      await transfer(tester);
      expect(userLikedSongsList.value, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('legacy newly resolved is disabled and leaves all mode usable', (
    tester,
  ) async {
    await openPage(tester);
    await choose(tester, 'Only newly resolved songs');
    expect(find.text('Previous tracking is unknown'), findsOneWidget);
    await review(tester);
    expect(
      tester
          .widget<SpotifyImportConfirmationDialog>(
            find.byType(SpotifyImportConfirmationDialog),
          )
          .preview
          .selectedCount,
      3,
    );
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(
      Hive.box('user').get('spotifyImportMetadata')[importRoutingBaselineKey],
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'newly resolved includes changed unselected row and becomes empty after transfer',
    (tester) async {
      await tester.runAsync(() async {
        await const SpotifyImportDestinationService().route(
          snapshot: await const SpotifyImportDestinationService()
              .loadSnapshot(),
          requestedCount: 1,
          destinationKind: SpotifyImportDestinationKind.likedSongs,
        );
        final rows = List<Map>.from(
          Hive.box('user').get('spotifyMatchResults'),
        );
        rows[1] = Map.from(rows[1])
          ..['bestCandidate'] = {
            'ytid': 'new-alternative',
            'title': 'New alternative',
          };
        await Hive.box('user').put('spotifyMatchResults', rows);
      });
      await openPage(tester);
      await choose(tester, 'Only newly resolved songs');
      await review(tester);
      expect(
        tester
            .widget<SpotifyImportConfirmationDialog>(
              find.byType(SpotifyImportConfirmationDialog),
            )
            .preview
            .selectedSongs
            .single['ytid'],
        'new-alternative',
      );
      await transfer(tester);
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'new-alternative',
        'fixture-1',
      ]);
      await review(tester);
      expect(find.byType(SpotifyImportConfirmationDialog), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Choose at least one resolved song.'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Choose at least one resolved song.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'first-N stays selected after transfer and a repeat remains idempotent',
    (tester) async {
      await tester.pumpWidget(
        priorityReviewApp(
          child: SpotifyImportDestinationPage(initialSnapshot: snapshot),
          brightness: Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      final exactAmount = find.text('Choose an exact amount');
      await tester.scrollUntilVisible(exactAmount, 300);
      await tester.tap(exactAmount);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Review'));
      });
      await tester.pumpAndSettle();
      await transfer(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1',
      );
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'fixture-1',
      ]);
      await tester.runAsync(() async {
        await tester.tap(find.text('Review'));
      });
      await tester.pumpAndSettle();
      final dialog = tester.widget<SpotifyImportConfirmationDialog>(
        find.byType(SpotifyImportConfirmationDialog),
      );
      expect(dialog.preview.selectedCount, 1);
      expect(dialog.preview.newCount, 0);
      expect(dialog.preview.alreadyPresentCount, 1);
      await transfer(tester);
      expect(userLikedSongsList.value.map((song) => song['ytid']), [
        'fixture-1',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
