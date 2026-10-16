import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/screens/search_page.dart' show searchHistoryNotifier;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/widgets/custom_bar.dart';

import '../../tool/visual_review_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _ToastHandler toastHandler;
  setUpAll(initPriorityReviewTestPlugins);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('settings-scope-');
    Hive.init(root.path);
    await initPriorityReviewHive();
    resetPriorityReviewGlobals();
    toastHandler = _ToastHandler();
    audioHandler = toastHandler;
    await Hive.box('user').putAll({
      'likedSongs': [
        {'ytid': 'keep-liked'},
      ],
      'spotifyImportTracks': [
        {'sourceRow': 1, 'title': 'Keep imported'},
      ],
      'searchHistory': ['Fixture query'],
      'recentlyPlayedSongs': [
        {'ytid': 'fixture-recent'},
      ],
    });
    searchHistoryNotifier.value = ['Fixture query'];
    userRecentlyPlayed.value = [
      {'ytid': 'fixture-recent'},
    ];
  });
  tearDown(() async {
    await toastHandler.mediaItem.close();
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      priorityReviewApp(
        child: const Scaffold(body: SettingsPage()),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
  }

  String inventory() => jsonEncode({
    for (final name in ['user', 'settings', 'userNoBackup'])
      name: {
        for (final key in Hive.box(name).keys)
          key.toString(): Hive.box(name).get(key),
      },
  });

  testWidgets(
    'approved playback switch preserves its key and data on repeated reopen',
    (tester) async {
      await tester.runAsync(() async {
        await Hive.box(
          'settings',
        ).putAll({'offlineMode': false, 'keepSetting': 42});
      });
      final beforeUser = jsonEncode(Hive.box('user').toMap());
      final beforeOffline = jsonEncode(Hive.box('userNoBackup').toMap());
      NavigationManager.instance;
      for (var cycle = 0; cycle < 2; cycle++) {
        for (final value in [true, false]) {
          await pumpSettings(tester);
          final entry = find.ancestor(
            of: find.text('Offline mode'),
            matching: find.byType(CustomBar),
          );
          await tester.ensureVisible(entry);
          expect(
            find.textContaining(
              'Off: saved audio when available, otherwise YouTube',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('Spotify imports provide metadata only'),
            findsOneWidget,
          );
          final toggle = find.descendant(
            of: entry,
            matching: find.byType(Switch),
          );
          expect(tester.widget<Switch>(toggle).value, !value);
          await tester.runAsync(() async {
            await tester.tap(toggle);
            final deadline = DateTime.now().add(const Duration(seconds: 2));
            while (Hive.box('settings').get('offlineMode') != value &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            await Hive.box('settings').flush();
          });
          await tester.pumpAndSettle();
          expect(offlineMode.value, value);
          expect(tester.widget<Switch>(toggle).value, value);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            await Hive.close();
            await initPriorityReviewHive();
          });
          reloadSettingsStateFromStorage();
          expect(offlineMode.value, value);
          expect(Hive.box('settings').toMap(), {
            'offlineMode': value,
            'keepSetting': 42,
          });
          expect(jsonEncode(Hive.box('user').toMap()), beforeUser);
          expect(jsonEncode(Hive.box('userNoBackup').toMap()), beforeOffline);
        }
      }
    },
  );

  testWidgets('all destructive data dialogs cancel without changing any box', (
    tester,
  ) async {
    await pumpSettings(tester);
    final before = inventory();
    for (final label in [
      'Clear search history',
      'Clear recently played',
      'Clear listening stats',
      'Delete downloads',
    ]) {
      final entry = find.text(label);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget, reason: label);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(inventory(), before, reason: label);
      expect(tester.takeException(), isNull, reason: label);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'confirmed history clearing preserves imports and likes after reopen',
    (tester) async {
      await pumpSettings(tester);
      for (final label in ['Clear search history', 'Clear recently played']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Clear'));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await Hive.box('user').flush();
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Hive.close();
        await initPriorityReviewHive();
      });
      expect(Hive.box('user').get('searchHistory'), isNull);
      expect(Hive.box('user').get('recentlyPlayedSongs'), isNull);
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'keep-liked'},
      ]);
      expect(Hive.box('user').get('spotifyImportTracks'), [
        {'sourceRow': 1, 'title': 'Keep imported'},
      ]);
    },
  );

  testWidgets(
    'confirmed stats clearing survives reopen and preserves library',
    (tester) async {
      final stats = createEmptyListeningStats(
        DateTime.now().year,
        currentMonthKey: listeningStatsMonthKey(DateTime.now()),
      );
      (stats['currentMonth'] as Map)['totalSeconds'] = 120;
      await tester.runAsync(() async {
        await Hive.box('user').put(ListeningStatsService.storageKey, stats);
      });
      listeningStatsService.reload();
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Clear listening stats'));
      await tester.tap(find.text('Clear listening stats'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Delete'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await Hive.box('user').flush();
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Hive.close();
        await initPriorityReviewHive();
      });
      final cleared =
          Hive.box('user').get(ListeningStatsService.storageKey) as Map;
      expect((cleared['currentMonth'] as Map)['totalSeconds'], 0);
      expect(cleared['history'], isEmpty);
      expect(Hive.box('user').get('likedSongs'), [
        {'ytid': 'keep-liked'},
      ]);
      expect(Hive.box('user').get('spotifyImportTracks'), [
        {'sourceRow': 1, 'title': 'Keep imported'},
      ]);
      listeningStatsService.reload();
    },
  );
}

class _ToastHandler extends Fake implements MusifyAudioHandler {
  @override
  final mediaItem = BehaviorSubject<MediaItem?>.seeded(null);

  @override
  void resetListeningStatsSession({
    bool countCurrentTick = false,
    bool flushStats = true,
  }) {}

  @override
  void startListeningStatsSessionIfNeeded() {}
}
