import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/widgets/custom_search_bar.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, Completer<List<dynamic>>> pending;

  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('search-lifecycle-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    searchHistoryNotifier.value = [];
    pending = {};
  });
  tearDown(() async {
    await Hive.close();
    final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final fixtureRoot = await root.resolveSymbolicLinks();
    final expectedPrefix =
        '$temporaryRoot${Platform.pathSeparator}search-lifecycle-';
    if (!fixtureRoot.startsWith(expectedPrefix)) {
      throw StateError(
        'Refusing to delete outside the owned fixture directory',
      );
    }
    await root.delete(recursive: true);
  });

  List<dynamic> song(String title) => [
    {'ytid': title, 'title': title, 'artist': 'Owned fixture artist'},
  ];

  Future<void> pumpSearch(
    WidgetTester tester, {
    SearchLoader? artistSearch,
  }) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: SearchPage(
          songSearch: (query) =>
              (pending[query] ??= Completer<List<dynamic>>()).future,
          artistSearch: artistSearch ?? (_) async => [],
          playlistSearch: (_, _) async => [],
          suggestionSearch: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String query) async {
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    bar.controller.text = query;
    await tester.runAsync(() async {
      bar.onSubmitted(query);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Hive.box('user').flush();
    });
    await tester.pump();
  }

  Future<void> complete(WidgetTester tester, String query, String title) async {
    await tester.runAsync(() async {
      pending[query]!.complete(song(title));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('an older search cannot replace newer completed results', (
    tester,
  ) async {
    await pumpSearch(tester);
    await submit(tester, 'first query');
    await submit(tester, 'second query');
    await complete(tester, 'second query', 'Current recording');
    expect(find.text('Current recording'), findsOneWidget);
    await complete(tester, 'first query', 'Stale recording');
    expect(find.text('Current recording'), findsOneWidget);
    expect(find.text('Stale recording'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an older completion cannot stop the current loading indicator', (
    tester,
  ) async {
    await pumpSearch(tester);
    await submit(tester, 'first query');
    await submit(tester, 'second query');
    await complete(tester, 'first query', 'Stale recording');
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    expect(bar.loadingProgressNotifier!.value, isTrue);
    await complete(tester, 'second query', 'Current recording');
    expect(bar.loadingProgressNotifier!.value, isFalse);
    expect(find.text('Current recording'), findsOneWidget);
  });

  testWidgets('leaving Search while a request completes causes no exception', (
    tester,
  ) async {
    await pumpSearch(tester);
    await submit(tester, 'pending query');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      pending['pending query']!.complete(song('Late recording'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the query cannot restore a pending old result', (
    tester,
  ) async {
    await pumpSearch(tester);
    await submit(tester, 'pending query');
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    bar.controller.clear();
    bar.onChanged!('');
    await tester.pump();
    await complete(tester, 'pending query', 'Late recording');
    expect(find.text('Late recording'), findsNothing);
    expect(bar.loadingProgressNotifier!.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed new query does not retain the previous song results', (
    tester,
  ) async {
    await pumpSearch(tester);
    await submit(tester, 'first query');
    await complete(tester, 'first query', 'Previous recording');
    expect(find.text('Previous recording'), findsOneWidget);
    await submit(tester, 'failed query');
    await tester.runAsync(() async {
      pending['failed query']!.completeError(
        StateError('Owned search failure'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Previous recording'), findsNothing);
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    expect(bar.loadingProgressNotifier!.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a current artist fallback still returns its intended songs', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      artistSearch: (_) async => [
        {'ytid': 'fixture-artist', 'title': 'Owned fixture artist'},
      ],
    );
    await submit(tester, 'artist lookup');
    await tester.runAsync(() async {
      pending['artist lookup']!.complete([]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(pending.containsKey('Owned fixture artist'), isTrue);
    await complete(tester, 'Owned fixture artist', 'Intended recording');
    expect(find.text('Intended recording'), findsOneWidget);
    expect(pending.containsKey('Owned fixture artist songs'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a superseded artist fallback makes no further requests', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      artistSearch: (query) async => query == 'artist lookup'
          ? [
              {'ytid': 'fixture-artist', 'title': 'Owned fixture artist'},
            ]
          : [],
    );
    await submit(tester, 'artist lookup');
    await tester.runAsync(() async {
      pending['artist lookup']!.complete([]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await submit(tester, 'current query');
    await complete(tester, 'current query', 'Current recording');
    await tester.runAsync(() async {
      pending['Owned fixture artist']!.complete([]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Current recording'), findsOneWidget);
    expect(pending.containsKey('Owned fixture artist songs'), isFalse);
    expect(pending.containsKey('Owned fixture artist music'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
