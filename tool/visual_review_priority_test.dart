import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/home_page.dart';
import 'package:musify/screens/library_page.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/widgets/offline_search_placeholder.dart';

import 'visual_review_harness.dart';

void main() {
  late Directory hiveRoot;

  setUpAll(() async {
    initPriorityReviewTestPlugins();
    await loadVisualReviewFonts();
  });

  setUp(() async {
    hiveRoot = await Directory.systemTemp.createTemp('visual-review-priority-');
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

  group('Phase 2A priority visual regression (core app)', () {
    testWidgets('navigation shell on settings tab (light)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: priorityReviewShellFrame(
            selectedIndex: 3,
            body: const SettingsPage(),
          ),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );
      await scrollToText(tester, 'Data safety');

      expect(find.byType(NavigationBar), findsOneWidget);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          'visual_review_goldens/priority_shell_settings_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('navigation shell on library tab (compact dark)', (
      tester,
    ) async {
      seedPriorityLibraryPopulated();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          reducedMotion: true,
          child: priorityReviewShellFrame(
            selectedIndex: 2,
            body: const LibraryPage(),
          ),
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
      );

      expect(find.text('Road Trip Mix'), findsWidgets);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          'visual_review_goldens/priority_shell_library_dark_compact.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('home populated playlists (light)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const HomePage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );

      expect(find.text('Musify.'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_home_populated_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('search history populated state (light)', (tester) async {
      seedPrioritySearchHistory();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          child: const SearchPage(),
        ),
        viewport: visualReviewStandardPhone,
      );

      expect(find.text('Midnight Drive'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_search_history_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('search offline placeholder (compact dark)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          child: const OfflineSearchPlaceholder(),
        ),
        viewport: visualReviewCompactPhone,
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_search_offline_dark_compact.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('library populated playlists (light)', (tester) async {
      seedPriorityLibraryPopulated();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const LibraryPage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );

      expect(find.text('Road Trip Mix'), findsWidgets);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_library_populated_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('library offline empty state (compact dark)', (tester) async {
      seedPriorityLibraryOfflineEmpty();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          child: const LibraryPage(),
        ),
        viewport: visualReviewCompactPhone,
      );

      expect(find.text('Offline mode'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_library_offline_empty_dark_compact.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('settings data safety section (light)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const SettingsPage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );
      await scrollToText(tester, 'Data safety');

      expect(find.text('Create verified backup'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_settings_data_safety_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('settings data safety section (compact dark)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          reducedMotion: true,
          child: const SettingsPage(),
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
      );
      await scrollToText(tester, 'Data safety');

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_settings_data_safety_dark_compact.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('settings data safety at elevated text scale', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const SettingsPage(),
          textScale: 2,
        ),
        viewport: visualReviewStandardPhone,
        textScale: 2,
        reducedMotion: true,
      );
      await scrollToText(tester, 'Data safety');

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_settings_data_safety_text_scale.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('core destructive confirmation dialog (light)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityCoreConfirmationDialogScreen(Brightness.light),
        viewport: visualReviewStandardPhone,
      );

      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile(
          'visual_review_goldens/priority_core_confirm_dialog_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('spotify matching empty import state (compact dark)', (
      tester,
    ) async {
      await clearPrioritySpotifyMatchingData();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          child: const SpotifyMatchingPage(),
        ),
        viewport: visualReviewCompactPhone,
        settle: false,
      );
      await waitForPriorityText(tester, 'No saved import yet');

      expect(find.text('No saved import yet'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_spotify_matching_empty_dark_compact.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });
  });
}
