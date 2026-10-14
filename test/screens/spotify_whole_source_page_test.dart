import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  late Directory root;
  const service = SpotifyImportDestinationService();
  late SpotifyImportDestinationSnapshot snapshot;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('whole-source-page-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    await Hive.box('user').putAll({
      'likedSongs': [
        {'ytid': 'keep-owner'},
      ],
      'spotifyImportTracks': [
        for (var row = 1; row <= 3; row++)
          {
            'sourceRow': row,
            'title': 'Owned source $row',
            'artist': 'Owned artist',
          },
      ],
      'spotifyMatchResults': [
        for (var row = 1; row <= 3; row++)
          {
            'sourceRow': row,
            'status': 'matched',
            'bestCandidate': {
              'ytid': 'owned-$row',
              'title': 'Owned recording $row',
              'artist': 'Owned artist',
            },
          },
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'whole-ui',
        'fileName': 'owned.csv',
        'validTrackCount': 3,
        'rejectedRowCount': 0,
      },
    });
    snapshot = await service.loadSnapshot();
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            textScaler: TextScaler.linear(2),
          ),
          child: SpotifyImportDestinationPage(initialSnapshot: snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Whole source recordings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> exclude(WidgetTester tester) async {
    await tester.runAsync(() async {
      final rows = (Hive.box('user').get('spotifyMatchResults') as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      rows.last['status'] = 'excluded';
      await Hive.box('user').put('spotifyMatchResults', rows);
    });
  }

  testWidgets(
    'compact large-text whole preview rejects a newer exclusion at confirmation',
    (tester) async {
      await open(tester);
      expect(tester.takeException(), isNull);
      final control = find.descendant(
        of: find.byKey(const ValueKey('whole-source-selection')),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(control).onTap, isNotNull);
      await tester.tap(find.text('Whole source recordings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer songs'), findsOneWidget);
      final metadata = Hive.box('user').get('spotifyImportMetadata');
      await exclude(tester);
      await tester.tap(find.text('Transfer songs'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Whole-source readiness changed'),
        ),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Whole-source readiness changed'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Whole-source readiness changed'),
        findsOneWidget,
      );
      expect(
        (Hive.box('user').get('likedSongs') as List).single['ytid'],
        'keep-owner',
      );
      expect(Hive.box('user').get('spotifyImportMetadata'), metadata);
      expect((metadata as Map).containsKey(importRoutingPendingKey), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'excluded rows disable whole claim while explicit partial all-resolved review remains usable',
    (tester) async {
      await exclude(tester);
      await tester.runAsync(() async {
        snapshot = await service.loadSnapshot();
      });
      await open(tester);
      final control = find.descendant(
        of: find.byKey(const ValueKey('whole-source-selection')),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(control).onTap, isNull);
      await tester.tap(find.text('Whole source recordings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer songs'), findsOneWidget);
      expect(
        service
            .selectSongs(
              snapshot,
              3,
              selectionKind: SpotifyImportSelectionKind.all,
            )
            .length,
        2,
      );
      expect(
        (Hive.box('user').get('likedSongs') as List).single['ytid'],
        'keep-owner',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
