import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/constants/app_constants.dart'
    show recommendedCubesNumber;
import 'package:musify/screens/about_page.dart';
import 'package:musify/screens/home_page.dart';
import 'package:musify/screens/library_page.dart';
import 'package:musify/screens/playlist_folder_page.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/screens/time_machine_page.dart';
import 'package:musify/services/common_services.dart' show globalSongs;
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/widgets/listening_recap_card.dart';
import 'package:musify/widgets/offline_search_placeholder.dart';

import 'visual_review_harness.dart';

/// Fixed preview fixture for the populated Time Machine page golden.
///
/// Deterministic and render-only: bypasses the listening stats service and
/// Hive entirely via [TimeMachinePage.previewData], so it does not depend on
/// the wall clock, persisted stats, or network image loading.
const priorityTimeMachinePreviewData = TimeMachinePreviewData(
  periodTitle: 'June 2026',
  periodLabel: 'June 2026',
  minutes: 128,
  previewSongs: [
    {
      'ytid': 'visual-tm-1',
      'title': 'Midnight Drive',
      'artist': 'The Night Signals',
    },
    {'ytid': 'visual-tm-2', 'title': 'Golden Hour', 'artist': 'Mara June'},
  ],
  hasMoreSongs: true,
);

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
      seedPriorityHomeRecommendations();
      final seededGlobalSongs = List<Map>.from(globalSongs);
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
      expect(find.text('Midnight Drive'), findsWidgets);
      // getRecommendedSongs() only reaches the live-YouTube fallback when
      // globalSongs is empty; if that path were hit, globalSongs would be
      // reassigned (fetched data, or left empty on failure). Asserting it is
      // unchanged proves the deterministic seed was used, not a network
      // fetch.
      expect(
        globalSongs,
        equals(seededGlobalSongs),
        reason:
            'globalSongs changed during the Home golden, which means '
            'getRecommendedSongs() reached its live-YouTube fallback '
            'instead of using the deterministic seed.',
      );
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

  group('Phase 3 low-risk screens visual regression', () {
    testWidgets('about page (light)', (tester) async {
      debugNetworkImageHttpClientProvider = PriorityFakeHttpClient.new;
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const AboutPage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );

      expect(find.text('Musify'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('visual_review_goldens/priority_about_light.png'),
      );
      await completePriorityReviewTest(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('about page (compact dark)', (tester) async {
      debugNetworkImageHttpClientProvider = PriorityFakeHttpClient.new;
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          reducedMotion: true,
          child: const AboutPage(),
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
      );

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_about_compact_dark.png',
        ),
      );
      await completePriorityReviewTest(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('playlist folder populated (light)', (tester) async {
      userPlaylistFolders.value = [
        {
          'id': 'folder-1',
          'name': 'Road Trip',
          'playlists': [
            {
              'ytid': 'p1',
              'title': 'Midnight Drive',
              'source': 'user-created',
              'image': null,
            },
            {
              'ytid': 'p2',
              'title': 'Golden Hour',
              'source': 'user-created',
              'image': null,
            },
          ],
          'createdAt': 0,
        },
      ];
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const PlaylistFolderPage(
            folderId: 'folder-1',
            folderName: 'Road Trip',
          ),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );

      expect(find.text('Midnight Drive'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_playlist_folder_populated_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('playlist folder empty state (compact dark)', (tester) async {
      userPlaylistFolders.value = [
        {
          'id': 'folder-1',
          'name': 'Road Trip',
          'playlists': [],
          'createdAt': 0,
        },
      ];
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          reducedMotion: true,
          child: const PlaylistFolderPage(
            folderId: 'folder-1',
            folderName: 'Road Trip',
          ),
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
      );

      expect(
        find.text(
          'This folder is empty. Add playlists to organize your music.',
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_playlist_folder_empty_compact_dark.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('time machine empty state (light)', (tester) async {
      wrappedEnabled.value = false;
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const TimeMachinePage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
      );

      expect(find.text('No listening stats yet'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_time_machine_empty_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('time machine populated page (light)', (tester) async {
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.light,
          reducedMotion: true,
          child: const TimeMachinePage(
            previewData: priorityTimeMachinePreviewData,
          ),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
        settle: false,
      );
      await pumpPriorityReviewFrames(tester);

      expect(find.text('Time Machine'), findsOneWidget);
      expect(find.text('June 2026'), findsWidgets);
      expect(find.byIcon(FluentIcons.share_24_regular), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('Midnight Drive'), findsOneWidget);
      expect(find.text('Golden Hour'), findsOneWidget);
      expect(find.text('Tap to view'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_time_machine_populated_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('listening recap card (compact dark)', (tester) async {
      // Golden-covers the restyled recap card directly with fixed literal
      // props. The populated Time Machine page golden uses
      // [TimeMachinePreviewData] via [TimeMachinePage.previewData] for full
      // page composition coverage.
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewApp(
          brightness: Brightness.dark,
          reducedMotion: true,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(10),
              child: ListeningRecapCard(
                periodLabel: 'July 2026',
                minutes: 128,
                songs: const [
                  {
                    'ytid': 's1',
                    'title': 'Midnight Drive',
                    'artist': 'The Night Signals',
                  },
                  {'ytid': 's2', 'title': 'Golden Hour', 'artist': 'Mara June'},
                ],
                onSongTap: (_) {},
              ),
            ),
          ),
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
      );

      expect(find.text('128'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_listening_recap_card_compact_dark.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });
  });

  group('Phase 4A shell/Home pre-restyle baseline', () {
    // Every test in this group renders Home, whose general
    // suggested-playlists rail is backed by `getPlaylists()`
    // (lib/services/playlists_manager.dart), which does
    // `List<Map>.from(playlists)..shuffle()` — an *unseeded* shuffle over
    // the built-in, always-non-empty `playlists` catalog — and takes the
    // first `recommendedCubesNumber`. That makes two things non-deterministic
    // per run, not one: which catalog entries appear, and (since real
    // entries carry real external `image` URLs) whether each cube's network
    // artwork fetch fails before or after the golden snapshot is taken.
    // Neither is fixable by waiting longer or clearing caches (confirmed:
    // still flaky after both, including on real Linux CI runs of the exact
    // same commit producing different pixel output). The only fully
    // deterministic fix is to replace the catalog with a fixed, image-free
    // fixture for the duration of this group, so every cube renders the
    // same generic placeholder regardless of shuffle order or network state.
    late List<Map> originalCatalogPlaylists;

    setUp(() async {
      // The real BottomNavigationPage reads the global `audioHandler`
      // directly (mini-player visibility stream), unlike the fixture-only
      // `priorityReviewShellFrame` used by the Phase 2A shell goldens above.
      await bindPriorityReviewAudioHandler();

      originalCatalogPlaylists = List<Map>.from(playlists);
      playlists = List.generate(
        recommendedCubesNumber,
        (i) => {'ytid': 'phase4a-catalog-fixture-$i', 'title': 'Fixture $i'},
      );
    });

    tearDown(() {
      playlists = originalCatalogPlaylists;
    });

    testWidgets('real shell on Home tab (compact, light)', (tester) async {
      seedPriorityHomeRecommendations();
      final router = buildPriorityShellNavRouter();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewShellAppSized(
          router: router,
          brightness: Brightness.light,
          viewSize: visualReviewCompactPhone,
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
        // The general suggested-playlists rail's catalog artwork attempts a
        // real (mocked-to-fail) network fetch with its own retry/backoff;
        // a short settle timeout races that against the fetch failing,
        // producing an intermittent extra "broken image" placeholder icon.
        // A generous timeout lets the failure fully resolve before the
        // golden snapshot instead of racing it.
        settleTimeout: const Duration(seconds: 10),
      );

      expect(find.text('Musify.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          'visual_review_goldens/priority_shell_home_compact_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('real shell on Home tab (wide, NavigationRail, light)', (
      tester,
    ) async {
      seedPriorityHomeRecommendations();
      const wideViewport = Size(900, 800);
      final router = buildPriorityShellNavRouter();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewShellAppSized(
          router: router,
          brightness: Brightness.light,
          viewSize: wideViewport,
        ),
        viewport: wideViewport,
        reducedMotion: true,
        settleTimeout: const Duration(seconds: 10),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          'visual_review_goldens/priority_shell_home_wide_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('real shell on Home tab, offline (compact, dark)', (
      tester,
    ) async {
      seedPriorityHomeRecommendations();
      offlineMode.value = true;
      final router = buildPriorityShellNavRouter();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewShellAppSized(
          router: router,
          brightness: Brightness.dark,
          viewSize: visualReviewCompactPhone,
        ),
        viewport: visualReviewCompactPhone,
        reducedMotion: true,
        settleTimeout: const Duration(seconds: 10),
      );

      expect(find.text('Search'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          'visual_review_goldens/priority_shell_home_offline_compact_dark.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('home nothing-personalized-yet state (light)', (tester) async {
      seedPriorityHomeEmpty();
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewAppSized(
          brightness: Brightness.light,
          reducedMotion: true,
          viewSize: visualReviewStandardPhone,
          child: const HomePage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
        settleTimeout: const Duration(seconds: 10),
      );

      expect(find.text('Musify.'), findsOneWidget);
      expect(find.text('Recommended for you'), findsNothing);
      expect(find.text('Listening stats'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_home_empty_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });

    testWidgets('home with announcement banner (light)', (tester) async {
      seedPriorityHomeRecommendations();
      announcementURL.value = 'https://example.com/announcement';
      await pumpPriorityGolden(
        tester,
        widget: priorityReviewAppSized(
          brightness: Brightness.light,
          reducedMotion: true,
          viewSize: visualReviewStandardPhone,
          child: const HomePage(),
        ),
        viewport: visualReviewStandardPhone,
        reducedMotion: true,
        settleTimeout: const Duration(seconds: 10),
      );

      expect(find.byIcon(FluentIcons.megaphone_24_filled), findsOneWidget);
      expect(
        find.byIcon(FluentIcons.dismiss_circle_24_regular),
        findsOneWidget,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'visual_review_goldens/priority_home_announcement_light.png',
        ),
      );
      await completePriorityReviewTest(tester);
    });
  });
}
