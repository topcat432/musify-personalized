import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/widgets/listening_recap_card.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  late Directory hiveRoot;

  setUpAll(() {
    initPriorityReviewTestPlugins();
  });

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('recap-card-test-');
    Hive.init(hiveRoot.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveRoot.exists()) {
      await hiveRoot.delete(recursive: true);
    }
  });

  List<Map<String, dynamic>> songs() => [
    {'ytid': 's1', 'title': 'Midnight Drive', 'artist': 'The Night Signals'},
    {'ytid': 's2', 'title': 'Golden Hour', 'artist': 'Mara June'},
  ];

  Future<void> pumpCard(
    WidgetTester tester, {
    required ValueChanged<int> onSongTap,
    List<Map<String, dynamic>>? songsOverride,
    int minutes = 128,
  }) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.dark,
        child: Scaffold(
          body: ListeningRecapCard(
            periodLabel: 'July 2026',
            minutes: minutes,
            songs: songsOverride ?? songs(),
            onSongTap: onSongTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the minutes, period label, and every song', (
    tester,
  ) async {
    await pumpCard(tester, onSongTap: (_) {});

    expect(find.text('128'), findsOneWidget);
    expect(find.textContaining('July 2026'), findsOneWidget);
    expect(find.text('Midnight Drive'), findsOneWidget);
    expect(find.text('Golden Hour'), findsOneWidget);
  });

  testWidgets('tapping a song reports its index', (tester) async {
    int? tappedIndex;
    await pumpCard(tester, onSongTap: (index) => tappedIndex = index);

    await tester.tap(find.text('Golden Hour'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 1);
  });

  testWidgets('renders with no songs without throwing', (tester) async {
    await pumpCard(
      tester,
      onSongTap: (_) {},
      songsOverride: const [],
      minutes: 0,
    );

    expect(find.text('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
