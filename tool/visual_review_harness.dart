import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/main.dart' show audioHandler, isFdroidBuild;
import 'package:musify/screens/bottom_navigation_page.dart';
import 'package:musify/screens/home_page.dart';
import 'package:musify/screens/library_page.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/app_typography.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player.dart';

/// Shared helpers for `tool/visual_review_*.dart` golden tests.
///
/// Keeps deterministic fixture data, Hive setup, and app wrappers in one place
/// so priority coverage (Phase 2A) does not duplicate the personalized-review
/// harness in `tool/visual_review_test.dart`.

const Color visualReviewSeedColor = Color(0xFF9B4F2A);

const Size visualReviewStandardPhone = Size(412, 915);
const Size visualReviewCompactPhone = Size(360, 720);

ColorScheme visualReviewScheme(Brightness brightness) => ColorScheme.fromSeed(
  seedColor: visualReviewSeedColor,
  brightness: brightness,
);

ThemeData reviewTheme(Brightness brightness) {
  final colors = visualReviewScheme(brightness);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'visualSans',
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: colors.surface,
      foregroundColor: colors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        color: colors.primary,
        fontFamily: 'paytoneOne',
        fontSize: 30,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      ),
    ),
  );
}

ThemeData productionReviewTheme(Brightness brightness) {
  final theme = getAppTheme(visualReviewScheme(brightness));
  // Golden legibility only: apply the loaded readable family to the theme's
  // text so production-theme renders show real glyphs instead of Ahem boxes.
  // `.apply(fontFamily:)` changes only the family — every production font
  // size, weight, letter-spacing, height, and color is preserved. The
  // app-bar's `paytoneOne` title lives in `appBarTheme` (not `textTheme`) and
  // is intentionally left untouched.
  final visualTextTheme = theme.textTheme.apply(fontFamily: 'visualSans');
  // `getAppTheme` already built and registered `AppTypography` from the
  // theme's original `textTheme` before this runs. `ThemeData.copyWith` does
  // not rebuild an already-registered extension, so leaving `extensions`
  // untouched here would make `AppTypography.of(context)` keep returning
  // styles from the unloaded original font — rebuild it from the
  // visualSans-applied text theme so every named role also renders real
  // glyphs. Every other extension (e.g. `AppSemanticColors`) is preserved
  // unchanged.
  final rebuiltExtensions = [
    ...theme.extensions.values.where(
      (extension) => extension is! AppTypography,
    ),
    AppTypography.fromTheme(visualTextTheme, theme.colorScheme),
  ];
  return theme.copyWith(
    textTheme: visualTextTheme,
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'visualSans'),
    extensions: rebuiltExtensions,
  );
}

void visualReviewSetViewport(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
  bool reducedMotion = false,
}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reducedMotion);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> loadVisualReviewFonts() async {
  final paytoneLoader = FontLoader('paytoneOne')
    ..addFont(rootBundle.load('assets/fonts/paytone/PaytoneOne-Regular.ttf'));
  final sansBytes = await _visualSansFont().readAsBytes();
  final sansLoader = FontLoader('visualSans')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(sansBytes)));
  final iconBytes = await _materialIconsFont().readAsBytes();
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
  // `fluentui_system_icons` ships its glyphs in two families used across the
  // app (`_*_regular` and `_*_filled`); load both from the bundled package
  // assets so FluentIcons render as real glyphs instead of square
  // placeholders. Its `IconData` carry `fontPackage: 'fluentui_system_icons'`,
  // so the engine's effective family is prefixed `packages/<pkg>/<family>` —
  // the FontLoader family name must match that prefixed form, not the bare
  // family declared in the package pubspec.
  final fluentRegularLoader =
      FontLoader(
        'packages/fluentui_system_icons/FluentSystemIcons-Regular',
      )..addFont(
        rootBundle.load(
          'packages/fluentui_system_icons/fonts/FluentSystemIcons-Regular.ttf',
        ),
      );
  final fluentFilledLoader =
      FontLoader('packages/fluentui_system_icons/FluentSystemIcons-Filled')
        ..addFont(
          rootBundle.load(
            'packages/fluentui_system_icons/fonts/FluentSystemIcons-Filled.ttf',
          ),
        );

  await Future.wait([
    paytoneLoader.load(),
    sansLoader.load(),
    iconLoader.load(),
    fluentRegularLoader.load(),
    fluentFilledLoader.load(),
  ]);
}

/// Mocks platform channels needed by cached artwork and the audio stack so
/// golden tests stay offline and deterministic.
void initPriorityReviewTestPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final tempRoot = Directory.systemTemp.createTempSync('vr-plugins-');

  messenger
    ..setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        switch (call.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationSupportDirectory':
          case 'getApplicationDocumentsDirectory':
            return '${tempRoot.path}${Platform.pathSeparator}${call.method}';
        }
        return null;
      },
    )
    ..setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async => null,
    )
    ..setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.client.methods'),
      (call) async => null,
    );
}

File _visualSansFont() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    r'C:\devtools\flutter\bin\cache\artifacts\material_fonts\Roboto-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }

  throw StateError('No readable sans-serif font found for visual reviews.');
}

File _materialIconsFont() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    r'C:\devtools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }

  throw StateError('Flutter Material Icons font was not found.');
}

Future<void> initPriorityReviewHive() async {
  await Hive.openBox('settings');
  await Hive.openBox('user');
  await Hive.openBox('userNoBackup');
  await Hive.openBox('cache');
}

void resetPriorityReviewGlobals() {
  offlineMode.value = false;
  wrappedEnabled.value = false;
  Hive.box('user').delete(ListeningStatsService.storageKey);
  listeningStatsService.reload();
  announcementURL.value = null;
  externalRecommendations.value = false;
  isFdroidBuild = false;

  searchHistoryNotifier.value = [];
  userPlaylists.value = [];
  userCustomPlaylists.value = [];
  userLikedPlaylists.value = [];
  userPlaylistFolders.value = [];
  pinnedPlaylistIds.value = [];
  onlinePlaylists.value = [];
  userLikedSongsList.value = [];
  userRecentlyPlayed.value = [];
  globalSongs = [];
}

/// Deterministic Home "Recommended for you" fixture.
///
/// [getRecommendedSongs] only reaches live YouTube (via
/// `getSongsFromPlaylist`) when [globalSongs] is empty, so seeding it here
/// keeps the Home golden offline. Exactly one song is seeded deliberately:
/// `_getRecommendationsFromMixedSources`/`_deduplicateAndShuffle` shuffle
/// the combined song list with an unseeded `Random`, so seeding two or more
/// songs would make their rendered order (and therefore the golden) flaky
/// from run to run. A single-element list cannot be reordered by a shuffle.
void seedPriorityHomeRecommendations() {
  globalSongs = [
    {
      'ytid': 'visual-home-rec-1',
      'title': 'Midnight Drive',
      'artist': 'The Night Signals',
    },
  ];
}

/// Deterministic Home "nothing personalized yet" fixture.
///
/// Clears every *user*-data-driven section (liked-only rail, recap,
/// recommended-for-you), each of which independently collapses to
/// `SizedBox.shrink()` in `home_page.dart` when its own data is empty. The
/// general suggested-playlists rail is intentionally left alone: it is
/// backed by `getPlaylists()`, which draws from the built-in
/// `playlists`/`playlistsDB`/`albumsDB` catalog (a static, non-user list),
/// so it is never actually empty in practice — a "fully blank Home" state
/// does not exist in the current app and is not invented here.
void seedPriorityHomeEmpty() {
  offlineMode.value = false;
  announcementURL.value = null;
  wrappedEnabled.value = false;
  userLikedPlaylists.value = [];
  userCustomPlaylists.value = [];
  userPlaylists.value = [];
  globalSongs = [];
}

void seedPriorityLibraryPopulated() {
  offlineMode.value = false;
  userCustomPlaylists.value = [
    {
      'ytid': 'visual-road-trip',
      'title': 'Road Trip Mix',
      'list': [
        {
          'ytid': 'visual-song-1',
          'title': 'Midnight Drive',
          'artist': 'The Night Signals',
        },
      ],
    },
    {
      'ytid': 'visual-late-night',
      'title': 'Late Night Focus',
      'list': [
        {
          'ytid': 'visual-song-2',
          'title': 'Golden Hour',
          'artist': 'Mara June',
        },
      ],
    },
  ];
  userLikedPlaylists.value = [
    {
      'ytid': 'PLDRZlcOmNR1ZpWYFy0TSUQSU-6vt0UIP2',
      'title': 'Teen Beats',
      'image':
          'https://i.scdn.co/image/ab67706f000000022149e95f03b2747e499b3f2f',
      'list': [],
    },
  ];
  pinnedPlaylistIds.value = ['visual-road-trip'];
}

void seedPriorityLibraryOfflineEmpty() {
  offlineMode.value = true;
  userPlaylists.value = [];
  userCustomPlaylists.value = [];
  userLikedPlaylists.value = [];
  userPlaylistFolders.value = [];
  userLikedSongsList.value = [];
}

void seedPrioritySearchHistory() {
  offlineMode.value = false;
  searchHistoryNotifier.value = [
    'Midnight Drive',
    'Golden Hour',
    'City Lights',
  ];
}

void seedPrioritySpotifyMatchingPopulated() {
  Hive.box('user')
    ..put('spotifyImportTracks', <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceRow': 1,
        'title': 'Midnight Drive',
        'artist': 'The Night Signals',
        'album': 'City Lights',
      },
      <String, dynamic>{
        'sourceRow': 2,
        'title': 'Golden Hour',
        'artist': 'Mara June',
        'album': 'Open Roads',
      },
    ])
    ..put('spotifyMatchResults', <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceRow': 1,
        'sourceTitle': 'Midnight Drive',
        'sourceArtist': 'The Night Signals',
        'status': 'matched',
        'score': 0.92,
      },
      <String, dynamic>{
        'sourceRow': 2,
        'sourceTitle': 'Golden Hour',
        'sourceArtist': 'Mara June',
        'status': 'needs_review',
        'score': 0.71,
      },
    ])
    ..put('spotifyImportMetadata', <String, dynamic>{
      'importSessionId': 'priority-review',
      'sourceName': 'Liked Songs from Spotify',
      'matchingStatus': 'paused',
      'nextTrackIndex': 1,
      'matchedCount': 1,
      'reviewCount': 1,
      'unmatchedCount': 0,
      'errorCount': 0,
      'excludedCount': 0,
    });
}

Future<void> clearPrioritySpotifyMatchingData() async {
  final box = Hive.box('user');
  await box.delete('spotifyImportTracks');
  await box.delete('spotifyMatchResults');
  await box.delete('spotifyImportMetadata');
}

Future<void> bindPriorityReviewAudioHandler({
  bool withPlayingMedia = false,
}) async {
  final handler = MusifyAudioHandler();
  audioHandler = handler;
  if (withPlayingMedia) {
    const mediaItem = MediaItem(
      id: 'visual-review-track',
      title: 'Midnight Drive',
      artist: 'The Night Signals',
      album: 'City Lights',
      duration: Duration(minutes: 3, seconds: 44),
    );
    handler.mediaItem.add(mediaItem);
    handler.queue.add([mediaItem]);
    handler.playbackState.add(
      PlaybackState(
        controls: const [MediaControl.pause, MediaControl.skipToNext],
        systemActions: const {MediaAction.seek},
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: const Duration(seconds: 42),
      ),
    );
  }
  addTearDown(() async {
    try {
      await handler.stop();
      await handler.customAction('clearQueue');
      await handler.audioPlayer.dispose();
    } catch (_) {}
  });
}

/// Navigation destinations mirror `BottomNavigationPage` without requiring the
/// production audio handler or router singleton.
List<NavigationDestination> priorityReviewNavDestinations({
  required bool isOffline,
}) {
  final destinations = <NavigationDestination>[
    const NavigationDestination(
      icon: Icon(FluentIcons.home_24_regular),
      selectedIcon: Icon(FluentIcons.home_24_filled),
      label: 'Home',
    ),
  ];
  if (!isOffline) {
    destinations.add(
      const NavigationDestination(
        icon: Icon(FluentIcons.search_24_regular),
        selectedIcon: Icon(FluentIcons.search_24_filled),
        label: 'Search',
      ),
    );
  }
  destinations.addAll([
    const NavigationDestination(
      icon: Icon(FluentIcons.library_24_regular),
      selectedIcon: Icon(FluentIcons.library_24_filled),
      label: 'Library',
    ),
    const NavigationDestination(
      icon: Icon(FluentIcons.settings_24_regular),
      selectedIcon: Icon(FluentIcons.settings_24_filled),
      label: 'Settings',
    ),
  ]);
  return destinations;
}

/// Shell chrome fixture: production NavigationBar + real tab body, without the
/// production audio stack or router singleton.
Widget priorityReviewShellFrame({
  required Widget body,
  required int selectedIndex,
  bool isOffline = false,
}) {
  return Scaffold(
    body: body,
    bottomNavigationBar: NavigationBar(
      selectedIndex: selectedIndex,
      destinations: priorityReviewNavDestinations(isOffline: isOffline),
    ),
  );
}

Widget priorityReviewApp({
  required Widget child,
  required Brightness brightness,
  bool useProductionTheme = true,
  double textScale = 1,
  bool reducedMotion = false,
}) {
  final theme = useProductionTheme
      ? productionReviewTheme(brightness)
      : reviewTheme(brightness);
  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reducedMotion,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// Same wiring as [priorityReviewApp], but derives `MediaQueryData` from the
/// test view (`MediaQueryData.fromView`) instead of a bare `MediaQueryData`.
/// See [priorityReviewShellAppSized]'s doc comment for why this matters:
/// `Home`'s own layout (`playlistHeight = MediaQuery.sizeOf(context).height *
/// ...`) genuinely depends on a correct `MediaQuery.size`, which
/// `priorityReviewApp` cannot provide.
Widget priorityReviewAppSized({
  required Widget child,
  required Brightness brightness,
  required Size viewSize,
  bool useProductionTheme = true,
  double textScale = 1,
  bool reducedMotion = false,
}) {
  final theme = useProductionTheme
      ? productionReviewTheme(brightness)
      : reviewTheme(brightness);
  return Builder(
    builder: (context) {
      final baseData = MediaQueryData.fromView(View.of(context));
      return MediaQuery(
        data: baseData.copyWith(
          size: viewSize,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.light,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );
    },
  );
}

GoRouter buildPriorityReviewShellRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const HomePage(),
        routes: [
          GoRoute(
            path: 'playlist/:playlistId',
            builder: (_, state) => PriorityShellBranchPlaceholder(
              label: 'Playlist ${state.pathParameters['playlistId']}',
            ),
          ),
          GoRoute(
            path: 'timeMachine',
            builder: (_, _) =>
                const PriorityShellBranchPlaceholder(label: 'Time Machine'),
          ),
        ],
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
      GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
}

/// Trivial placeholder body for shell branches that are out of scope for
/// Phase 4A (Search/Library/Settings) — only the tab index/label is asserted
/// for those branches, so their real screens are not needed here.
class PriorityShellBranchPlaceholder extends StatelessWidget {
  const PriorityShellBranchPlaceholder({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Text(label),
    );
  }
}

/// A real `StatefulShellRoute.indexedStack` router hosting the actual
/// production `BottomNavigationPage` widget (not a fixture mirror), so shell
/// tests exercise the real back-navigation, double-tap-reset, offline
/// tab-hiding, and compact/wide layout logic. The Home branch renders the
/// real `HomePage`; other branches are trivial placeholders since Search,
/// Library, and Settings are out of scope for this phase.
GoRouter buildPriorityShellNavRouter({String initialLocation = '/home'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => NoTransitionPage(
          child: BottomNavigationPage(child: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, _) =>
                    const PriorityShellBranchPlaceholder(label: 'Search'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) =>
                    const PriorityShellBranchPlaceholder(label: 'Library'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    const PriorityShellBranchPlaceholder(label: 'Settings'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Same wiring as [priorityReviewShellApp], but derives `MediaQueryData`
/// from the test view (`MediaQueryData.fromView`) instead of a bare
/// `MediaQueryData(...)`.
///
/// **Known pre-existing gap (not fixed here):** `priorityReviewApp` and
/// `priorityReviewShellApp` both construct a bare `MediaQueryData(...)`,
/// whose `size` defaults to `Size.zero` — it does not inherit the real
/// viewport size set via `tester.view.physicalSize`/`visualReviewSetViewport`.
/// Every existing priority/Phase-3 golden happens to test only narrow
/// viewports (`visualReviewStandardPhone`/`visualReviewCompactPhone`), so
/// this has never surfaced there, but it does mean any code reading
/// `MediaQuery.of(context).size` (not just layout constraints) sees
/// `Size.zero` in those tests today — including, notably, Home's own
/// `playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1`. Fixing
/// that in the two shared functions above would risk changing pixel output
/// for every existing committed golden (Search/Library/Settings/Spotify
/// included), which is out of bounds for a Home/shell-only phase — flagged
/// for a separately scoped harness fix rather than patched opportunistically
/// here. This function exists solely to unblock the one new capability this
/// phase needs (correct wide-vs-compact shell coverage) without touching the
/// shared, wider-blast-radius helpers.
Widget priorityReviewShellAppSized({
  required GoRouter router,
  required Brightness brightness,
  required Size viewSize,
  double textScale = 1,
  bool reducedMotion = false,
}) {
  final theme = productionReviewTheme(brightness);
  return Builder(
    builder: (context) {
      final baseData = MediaQueryData.fromView(View.of(context));
      return MediaQuery(
        data: baseData.copyWith(
          size: viewSize,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.light,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    },
  );
}

Widget priorityReviewShellApp({
  required GoRouter router,
  required Brightness brightness,
  double textScale = 1,
  bool reducedMotion = false,
}) {
  final theme = productionReviewTheme(brightness);
  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reducedMotion,
    ),
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> completePriorityReviewTest(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump();
}

Future<void> waitForPriorityText(
  WidgetTester tester,
  String text, {
  int maxPumps = 10,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump();
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for priority review text: "$text"');
}

Future<void> pumpPriorityReviewFrames(
  WidgetTester tester, {
  int frames = 6,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

Future<void> pumpPriorityGolden(
  WidgetTester tester, {
  required Widget widget,
  required Size viewport,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool reducedMotion = false,
  Duration settleTimeout = const Duration(seconds: 3),
  bool settle = true,
}) async {
  visualReviewSetViewport(
    tester,
    viewport,
    textScale: textScale,
    reducedMotion: reducedMotion,
  );
  await tester.pumpWidget(widget);
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(milliseconds: 400));
    // `pumpAndSettle`'s first positional parameter is the per-pump-step
    // duration, not a timeout; passing `settleTimeout` there left the
    // timeout at Flutter's 10-minute default, so a ticker/image/marquee
    // left running never failed near the intended timeout.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      settleTimeout,
    );
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> scrollToText(
  WidgetTester tester,
  String text, {
  double delta = 500,
}) async {
  final target = find.text(text);
  expect(
    target,
    findsOneWidget,
    reason: 'Expected text "$text" to exist in the widget tree.',
  );
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Core-app destructive confirmation dialog used across Settings and Library.
Widget priorityCoreConfirmationDialogScreen(Brightness brightness) {
  return priorityReviewApp(
    brightness: brightness,
    child: Scaffold(
      body: Center(
        child: ConfirmationDialog(
          confirmationMessage: 'Remove this playlist from your library?',
          submitMessage: 'Remove',
          isDangerous: true,
          onCancel: () {},
          onSubmit: () {},
        ),
      ),
    ),
  );
}

// A well-known 1x1 transparent PNG, used to satisfy any `Image.network` call
// (e.g. the About page's avatar) without depending on real network access.
final Uint8List _kPriorityTransparentImage = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _PriorityFake {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PriorityFakeHttpClientResponse extends _PriorityFake
    implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kPriorityTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kPriorityTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }
}

class _PriorityFakeHttpClientRequest extends _PriorityFake
    implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _PriorityFakeHttpClientResponse();
}

class PriorityFakeHttpClient extends _PriorityFake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _PriorityFakeHttpClientRequest();
}

/// Mini-player chrome with deterministic fake media metadata.
Widget priorityMiniPlayerScreen(Brightness brightness) {
  return priorityReviewApp(
    brightness: brightness,
    child: const Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: MiniPlayer(),
        ),
      ),
    ),
  );
}
