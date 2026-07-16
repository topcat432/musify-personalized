import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/screens/spotify_import_hub_page.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/personalized_update_service.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/spotify_import_destination_service.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/widgets/personalized_ui.dart';
import 'package:musify/widgets/personalized_update_dialog.dart';

void main() {
  late Directory foundationHiveRoot;

  setUpAll(_loadVisualReviewFonts);

  // The Phase 1 foundation-token goldens below render through the real
  // production `getAppTheme`, which lazily reads the `settings` Hive box
  // (for the pure-black preference). The rest of this file's goldens
  // intentionally use the lightweight `_reviewTheme` and do not need this.
  setUp(() async {
    foundationHiveRoot = await Directory.systemTemp.createTemp(
      'visual-review-theme-',
    );
    Hive.init(foundationHiveRoot.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    if (await foundationHiveRoot.exists()) {
      await foundationHiveRoot.delete(recursive: true);
    }
  });

  testWidgets('renders the import hub visual review', (tester) async {
    _setViewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.light),
        home: const SpotifyImportHubPage(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('visual_review_goldens/import_hub_light.png'),
    );
  });

  testWidgets('renders the destination flow on a standard phone', (
    tester,
  ) async {
    _setViewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.light),
        home: SpotifyImportDestinationPage(
          initialSnapshot: _visualDestinationSnapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('visual_review_goldens/import_destination_light.png'),
    );
  });

  testWidgets('renders the destination flow on a compact dark phone', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 720));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.dark),
        home: SpotifyImportDestinationPage(
          initialSnapshot: _visualDestinationSnapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'visual_review_goldens/import_destination_compact_dark.png',
      ),
    );
  });

  testWidgets('renders destination choices on a compact dark phone', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 720));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.dark),
        home: SpotifyImportDestinationPage(
          initialSnapshot: _visualDestinationSnapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add to an existing playlist'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        'visual_review_goldens/import_destination_options_compact_dark.png',
      ),
    );
  });

  testWidgets('renders four-digit counts in the transfer dialog', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 720));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.dark),
        home: Scaffold(
          body: SpotifyImportConfirmationDialog(
            preview: const SpotifyImportRoutePreview(
              selectedCount: 2619,
              newCount: 2619,
              alreadyPresentCount: 1250,
              unresolvedCount: 24,
            ),
            onCancel: () {},
            onConfirm: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2619'), findsOneWidget);
    expect(find.text('1250'), findsOneWidget);
    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile(
        'visual_review_goldens/import_destination_dialog_compact_dark.png',
      ),
    );
  });

  testWidgets('renders Quick Review on a standard phone', (tester) async {
    final player = _VisualAudioPlayer();
    addTearDown(player.dispose);
    _setViewport(tester, const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.light),
        home: SpotifyReviewSprintPage(
          dataSource: _VisualDataSource(_visualItems),
          audioPlayer: player,
          streamResolver: (songId) async => 'preview://$songId',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('visual_review_goldens/quick_review_light.png'),
    );
  });

  testWidgets('renders Quick Review on a compact dark phone', (tester) async {
    final player = _VisualAudioPlayer();
    addTearDown(player.dispose);
    _setViewport(tester, const Size(360, 720));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.dark),
        home: SpotifyReviewSprintPage(
          dataSource: _VisualDataSource(_visualItems),
          audioPlayer: player,
          streamResolver: (songId) async => 'preview://$songId',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('visual_review_goldens/quick_review_compact_dark.png'),
    );
  });

  testWidgets('renders the updater on a compact dark phone', (tester) async {
    final service = PersonalizedUpdateService();
    addTearDown(service.close);
    _setViewport(tester, const Size(360, 720));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _reviewTheme(Brightness.dark),
        home: Scaffold(
          body: PersonalizedUpdateDialog(
            check: _visualUpdateCheck,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile(
        'visual_review_goldens/personalized_update_compact_dark.png',
      ),
    );
  });

  // --- Phase 1 foundation-token evidence -----------------------------------
  //
  // Everything above renders through the lightweight `_reviewTheme`. The
  // goldens below render through the real production `getAppTheme` (see
  // `lib/theme/app_themes.dart`) so the token system introduced in
  // `docs/VISUAL_OVERHAUL_PLAN.md` Phase 1 is proven end-to-end: semantic
  // colors, typography roles, shape roles, and spacing all flow through a
  // real theme, not a test stand-in. Per that plan's Phase 1 scope, this is
  // representative foundation evidence, not a screen-by-screen visual
  // backfill (that is Phase 2+).
  group('Phase 1 foundation tokens (real getAppTheme)', () {
    for (final brightness in Brightness.values) {
      final suffix = brightness == Brightness.light ? 'light' : 'dark';

      testWidgets(
        'personalized/import surface renders through getAppTheme ($suffix)',
        (tester) async {
          _setViewport(tester, const Size(412, 915));
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _productionReviewTheme(brightness),
              home: const SpotifyImportHubPage(),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'visual_review_goldens/foundation_import_hub_$suffix.png',
            ),
          );
        },
      );

      testWidgets('dialog/sheet renders through getAppTheme ($suffix)', (
        tester,
      ) async {
        _setViewport(tester, const Size(412, 915));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _productionReviewTheme(brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showPersonalizedDestructiveConfirmation(
                      context: context,
                      title: 'Remove this track?',
                      message:
                          'It will be removed from your library. This '
                          'cannot be undone.',
                      confirmLabel: 'Remove track',
                    ),
                    child: const Text('Open confirmation'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open confirmation'));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(BottomSheet),
          matchesGoldenFile(
            'visual_review_goldens/foundation_destructive_sheet_$suffix.png',
          ),
        );
      });

      testWidgets('card/list surface renders through getAppTheme ($suffix)', (
        tester,
      ) async {
        _setViewport(tester, const Size(412, 915));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _productionReviewTheme(brightness),
            home: const _FoundationCardListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'visual_review_goldens/foundation_card_list_$suffix.png',
          ),
        );
      });

      testWidgets(
        'general content screen renders through getAppTheme ($suffix)',
        (tester) async {
          _setViewport(tester, const Size(412, 915));
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _productionReviewTheme(brightness),
              home: const _FoundationContentScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'visual_review_goldens/foundation_general_content_$suffix.png',
            ),
          );
        },
      );
    }
  });
}

ColorScheme _foundationScheme(Brightness brightness) => ColorScheme.fromSeed(
  seedColor: const Color(0xFF9B4F2A),
  brightness: brightness,
);

/// Real production `getAppTheme`, with the loaded readable family applied to
/// its text for golden legibility only. `.apply(fontFamily:)` changes only the
/// glyph family — production sizes/weights/spacing/colors are preserved — and
/// the app-bar's `paytoneOne` title (in `appBarTheme`, not `textTheme`) is left
/// untouched. Mirrors `productionReviewTheme` in `visual_review_harness.dart`.
ThemeData _productionReviewTheme(Brightness brightness) {
  final theme = getAppTheme(_foundationScheme(brightness));
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'visualSans'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'visualSans'),
  );
}

/// A synthetic "general content screen": ordinary Material widgets
/// (`AppBar`, `ListTile`, `Divider`) relying purely on the theme's default
/// `textTheme`/`colorScheme`, with no personalized-specific widgets. This
/// demonstrates the foundation tokens work for plain Material content, not
/// just the bespoke personalized primitives.
class _FoundationContentScreen extends StatelessWidget {
  const _FoundationContentScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foundation review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Section title',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Body copy rendered from the theme\'s default text theme, with '
            'no per-widget font-size overrides.',
          ),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.check_circle_outline_rounded),
            title: Text('A representative list row'),
            subtitle: Text('Uses the theme, not a literal color'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Another list row'),
            subtitle: Text('Consistent spacing and radii'),
          ),
        ],
      ),
    );
  }
}

/// A synthetic "card/list surface": `PersonalizedSurface`/`PersonalizedMetric`
/// composed into a small list, proving the shared primitives render
/// correctly against the real theme (not just the lightweight test theme
/// used elsewhere in this file).
class _FoundationCardListScreen extends StatelessWidget {
  const _FoundationCardListScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card and list surfaces')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PersonalizedSurface(
            child: Row(
              children: [
                Expanded(
                  child: PersonalizedMetric(label: 'Resolved', value: '2,619'),
                ),
                Expanded(
                  child: PersonalizedMetric(label: 'Needs review', value: '24'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const PersonalizedStatusBanner(
            title: 'Almost done',
            message: '24 tracks still need your review before importing.',
            tone: PersonalizedStatusTone.warning,
          ),
          const SizedBox(height: 12),
          const PersonalizedSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.music_note_rounded),
                  title: Text('Midnight Drive'),
                  subtitle: Text('The Night Signals'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.music_note_rounded),
                  title: Text('Golden Hour'),
                  subtitle: Text('Mara June'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ThemeData _reviewTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF9B4F2A),
    brightness: brightness,
  );
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

Future<void> _loadVisualReviewFonts() async {
  final paytoneLoader = FontLoader('paytoneOne')
    ..addFont(rootBundle.load('assets/fonts/paytone/PaytoneOne-Regular.ttf'));
  final sansBytes = await _visualSansFont().readAsBytes();
  final sansLoader = FontLoader('visualSans')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(sansBytes)));
  final iconBytes = await _materialIconsFont().readAsBytes();
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
  // Load both Fluent icon families from the bundled package assets so
  // FluentIcons render as real glyphs (matches the priority harness). The
  // package's `IconData` carry `fontPackage: 'fluentui_system_icons'`, so the
  // FontLoader family must use the engine's prefixed `packages/<pkg>/<family>`
  // form, not the bare family name.
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

File _visualSansFont() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
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
  if (flutterRoot != null) {
    final file = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) {
      return file;
    }
  }

  throw StateError('Flutter Material Icons font was not found.');
}

final List<Map<String, dynamic>> _visualItems = [
  {
    'sourceRow': 12,
    'sourceTitle': 'Midnight Drive',
    'sourceArtist': 'The Night Signals',
    'sourceAlbum': 'City Lights',
    'sourceIsrc': 'DEMO000012',
    'status': 'needs_review',
    'alternatives': [
      {
        'score': 0.93,
        'candidate': {
          'ytid': 'midnight-studio',
          'title': 'Midnight Drive',
          'artist': 'The Night Signals',
          'album': 'City Lights',
          'duration': 224,
          'sourceType': 'youtube_music_song',
        },
        'evidence': {
          'reasons': ['Exact title', 'Primary artist matches', 'Album matches'],
        },
      },
      {
        'score': 0.84,
        'candidate': {
          'ytid': 'midnight-live',
          'title': 'Midnight Drive (Live)',
          'artist': 'The Night Signals',
          'album': 'Live After Dark',
          'duration': 238,
          'sourceType': 'youtube_music_song',
        },
        'evidence': {
          'reasons': ['Exact artist', 'Live version detected'],
        },
      },
    ],
  },
  {
    'sourceRow': 13,
    'sourceTitle': 'Golden Hour',
    'sourceArtist': 'Mara June',
    'sourceAlbum': 'Open Roads',
    'sourceIsrc': 'DEMO000013',
    'status': 'needs_review',
    'alternatives': [
      {
        'score': 0.89,
        'candidate': {
          'ytid': 'golden-hour',
          'title': 'Golden Hour',
          'artist': 'Mara June',
          'album': 'Open Roads',
          'duration': 197,
          'sourceType': 'youtube_music_song',
        },
        'evidence': {
          'reasons': ['Exact title', 'Album matches'],
        },
      },
    ],
  },
];

final _visualDestinationSnapshot = SpotifyImportDestinationSnapshot(
  importSessionId: 'visual-preview',
  sourceName: 'Liked Songs from Spotify',
  resolvedSongs: List<Map<String, dynamic>>.generate(
    2619,
    (index) => {
      'ytid': 'visual-song-$index',
      'title': 'Visual Song $index',
      'artist': 'Visual Artist',
    },
  ),
  resolvedResultCount: 2619,
  unresolvedCount: 24,
  customPlaylists: [
    {'ytid': 'road-trip', 'title': 'Road Trip'},
    {'ytid': 'late-night', 'title': 'Late Night'},
  ],
);

final _visualUpdateCheck = PersonalizedUpdateCheck(
  availability: PersonalizedUpdateAvailability.available,
  installed: const InstalledAppIdentity(
    packageName: personalizedProductionPackage,
    versionCode: 100000198,
    signerSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ),
  manifest: PersonalizedUpdateManifest(
    versionCode: 100000200,
    versionName: '0.1.100000200',
    packageName: personalizedProductionPackage,
    signerSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    apkSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    apkUrl: Uri.parse(
      'https://github.com/topcat432/musify-personalized/releases/download/'
      'personalized-v0.1.100000200/musify-personalized-production.apk',
    ),
    sourceCommit: 'cccccccccccccccccccccccccccccccccccccccc',
    releaseNotes:
        'Faster testing updates, verified package identity, and smoother review motion.',
  ),
);

class _VisualDataSource implements SpotifyReviewSprintDataSource {
  _VisualDataSource(List<Map<String, dynamic>> items)
    : _items = items.map(Map<String, dynamic>.from).toList(growable: true);

  final List<Map<String, dynamic>> _items;

  @override
  Future<List<Map<String, dynamic>>> loadUnresolvedItems() async {
    return _items.map(Map<String, dynamic>.from).toList(growable: false);
  }

  @override
  Future<SpotifyResolutionResult> resolveItem({
    required Map<String, dynamic> item,
    required bool accept,
    Map<String, dynamic>? selectedAlternative,
  }) async {
    _items.removeWhere(
      (candidate) => candidate['sourceRow'] == item['sourceRow'],
    );
    return SpotifyResolutionResult(
      duplicatesApplied: 0,
      remainingUnresolved: _items.length,
    );
  }

  @override
  Future<SpotifyResolutionResult> excludeItem({
    required Map<String, dynamic> item,
  }) async {
    _items.removeWhere(
      (candidate) => candidate['sourceRow'] == item['sourceRow'],
    );
    return SpotifyResolutionResult(
      duplicatesApplied: 0,
      remainingUnresolved: _items.length,
    );
  }

  @override
  Future<int> bulkApproveCluster({
    required String key,
    required String importSessionId,
  }) async => 0;
}

class _VisualAudioPlayer implements ReviewSprintAudioPlayer {
  @override
  Stream<ReviewSprintAudioState> get stateStream =>
      const Stream<ReviewSprintAudioState>.empty();

  @override
  Future<void> setUrl(String url) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {}
}
