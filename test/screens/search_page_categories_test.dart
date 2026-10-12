import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/music_search_service.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';
import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('search-categories-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    searchHistoryNotifier.value = [];
  });
  tearDown(() async {
    await Hive.close();
    final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final fixtureRoot = await root.resolveSymbolicLinks();
    if (!fixtureRoot.startsWith(
      '$temporaryRoot${Platform.pathSeparator}search-categories-',
    )) {
      throw StateError(
        'Refusing to remove outside the owned fixture directory',
      );
    }
    await root.delete(recursive: true);
  });

  Map<String, dynamic> video(String id, String title, {int? duration}) => {
    'ytid': id,
    'title': title,
    'artist': 'Owned fixture channel',
    'duration': duration,
  };
  Future<void> search(
    WidgetTester tester,
    SearchLoader songs,
    SearchLoader videos, {
    SearchLoader? artists,
  }) async {
    await tester.pumpWidget(
      priorityReviewApp(
        brightness: Brightness.light,
        child: SearchPage(
          songSearch: songs,
          videoSearch: videos,
          artistSearch: artists ?? (_) async => [],
          playlistSearch: (_, _) async => [],
          suggestionSearch: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    bar.controller.text = 'Owned artist';
    await tester.runAsync(() async {
      bar.onSubmitted('Owned artist');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Hive.box('user').flush();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'typed long music and uncertain videos retain truthful categories and source order',
    (tester) async {
      final music = musicSearchSong(
        const MusicSong(
          id: 'long-recording',
          title: 'Owned complete symphony',
          artists: ['Owned composer', 'Owned orchestra'],
          album: 'Owned concert',
          duration: Duration(hours: 2),
          thumbnailUrl: 'https://example.invalid/art.jpg',
          explicit: true,
        ),
      );
      await search(
        tester,
        (_) async => [music],
        (_) async => [
          video('long-recording', 'Same exact video'),
          video('film', 'Owned documentary', duration: 5721),
          video('mix', 'Owned live DJ mix', duration: 10800),
          video('unknown', 'Uncertain recording'),
        ],
      );
      expect(find.text('Songs · YouTube Music'), findsOneWidget);
      expect(find.text('YouTube videos'), findsOneWidget);
      final rows = tester
          .widgetList<SongBar>(find.byType(SongBar))
          .map((row) => row.song as Map)
          .toList();
      expect(rows.map((row) => row['ytid']), [
        'long-recording',
        'film',
        'mix',
        'unknown',
      ]);
      expect(rows.first, containsPair('duration', 7200));
      expect(
        rows.first,
        containsPair('artist', 'Owned composer, Owned orchestra'),
      );
      expect(rows.first, containsPair('album', 'Owned concert'));
      expect(
        rows.first,
        containsPair('image', 'https://example.invalid/art.jpg'),
      );
      expect(rows.first, containsPair('sourceType', 'youtube_music_song'));
      expect(rows.first, containsPair('isExplicit', true));
      expect(rows.last['duration'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      '${fails ? 'failed' : 'empty'} typed lookup leaves video fallback discoverable',
      (tester) async {
        await search(tester, (_) async {
          if (fails) throw StateError('Owned metadata failure');
          return [];
        }, (_) async => [video('fallback', 'Owned live set', duration: 14400)]);
        expect(find.text('Songs · YouTube Music'), findsNothing);
        expect(find.text('YouTube videos'), findsOneWidget);
        expect(find.text('Owned live set'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed generic lookup retains typed music results', (
    tester,
  ) async {
    await search(tester, (_) async => [video('music', 'Owned provider song')], (
      _,
    ) async {
      throw StateError('Owned generic metadata failure');
    });
    expect(find.text('Songs · YouTube Music'), findsOneWidget);
    expect(find.text('Owned provider song'), findsOneWidget);
    expect(find.text('YouTube videos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available videos avoid repeated failed music fallback queries', (
    tester,
  ) async {
    var calls = 0;
    await search(
      tester,
      (_) async {
        calls++;
        throw StateError('Owned unavailable music lookup');
      },
      (_) async => [video('available', 'Owned available video')],
      artists: (_) async => [
        {'ytid': 'owned-artist', 'title': 'Owned artist'},
      ],
    );
    expect(calls, 1);
    expect(find.text('Owned available video'), findsOneWidget);
    expect(find.text('YouTube videos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing Search discards a late generic result', (tester) async {
    final pending = Completer<List<dynamic>>();
    await search(tester, (_) async => [], (_) => pending.future);
    final bar = tester.widget<CustomSearchBar>(find.byType(CustomSearchBar));
    bar.controller.clear();
    bar.onChanged!('');
    await tester.runAsync(() async {
      pending.complete([video('late', 'Owned late video')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Owned late video'), findsNothing);
    expect(find.text('YouTube videos'), findsNothing);
    expect(bar.loadingProgressNotifier!.value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
