import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/screens/spotify_import_hub_page.dart';
import 'package:musify/screens/spotify_review_sprint_page.dart';
import 'package:musify/services/review_sprint_audio_player.dart';
import 'package:musify/services/spotify_review_workflow_service.dart';

void main() {
  setUpAll(_loadVisualReviewFonts);

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

  await Future.wait([paytoneLoader.load(), sansLoader.load()]);
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
  Future<int> bulkApproveCluster(String key) async => 0;
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
