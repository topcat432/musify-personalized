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

ThemeData productionReviewTheme(Brightness brightness) =>
    getAppTheme(visualReviewScheme(brightness));

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

  await Future.wait([
    paytoneLoader.load(),
    sansLoader.load(),
    iconLoader.load(),
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

GoRouter buildPriorityReviewShellRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
      GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
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
    await tester.pumpAndSettle(settleTimeout);
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
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
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
