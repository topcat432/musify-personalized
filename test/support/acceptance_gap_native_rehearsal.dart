// Owned Android acceptance surface. Never imported by normal startup.
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/screens/equalizer_page.dart';
import 'package:musify/screens/settings_page.dart';
import 'package:musify/screens/spotify_import_page.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/spotify_import_session_service.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android rehearsal only');
  final normal = await getApplicationDocumentsDirectory();
  final scratch = Directory('${normal.path}/acceptance_gap_v1');
  await scratch.create(recursive: true);
  Hive.init(scratch.path);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(name);
  }
  applicationDirPath = scratch.path;
  await FilePaths.ensureDirectoriesExist();
  final user = Hive.box('user');
  if (!user.containsKey('gapSeeded')) {
    final stats = createEmptyListeningStats(
      DateTime.now().year,
      currentMonthKey: listeningStatsMonthKey(DateTime.now()),
    );
    (stats['currentMonth'] as Map)['totalSeconds'] = 120;
    await user.putAll({
      'gapSeeded': true,
      'likedSongs': [
        {'ytid': 'gap-keep-like', 'title': 'Owned retained like'},
      ],
      'searchHistory': ['Owned query'],
      'recentlyPlayedSongs': [
        {'ytid': 'gap-recent', 'title': 'Owned recent'},
      ],
      ListeningStatsService.storageKey: stats,
      'spotifyImportTracks': [
        for (var row = 1; row <= 50; row++)
          {'sourceRow': row, 'title': 'Owned row $row', 'artist': 'Synthetic'},
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'owned-gap-import',
        'fileName': 'owned-gap.csv',
        'matchingStatus': 'paused',
        'nextTrackIndex': 1,
      },
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'manually_matched',
          'bestCandidate': {'ytid': 'gap-retained-alternate'},
        },
      ],
      // Real matching checkpoint/pause logic without any provider lookup.
      'spotifyExcludedImportRows': [for (var row = 2; row <= 50; row++) '$row'],
    });
    await Hive.box('cache').put('owned-cache-marker', 'disposable');
    await Hive.box('settings').put('offlineMode', true);
    final audio = File(FilePaths.getAudioPath('gap-download'));
    await audio.writeAsBytes(List<int>.filled(128, 0));
    await Hive.box('userNoBackup').put('offlineSongs', [
      {
        'ytid': 'gap-download',
        'title': 'Owned removable fixture',
        'audioPath': audio.path,
      },
    ]);
  }
  reloadSongLibraryStateFromStorage();
  reloadPlaylistLibraryStateFromStorage();
  audioHandler = await AudioService.init(
    builder: MusifyAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.gokadzev.musify',
      androidNotificationChannelName: 'Musify',
      androidNotificationIcon: 'drawable/ic_launcher_foreground',
    ),
  );
  NavigationManager.instance;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const OwnedGapHome()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/settings/equalizer',
        builder: (_, _) => const EqualizerPage(),
      ),
      GoRoute(
        path: '/matching',
        builder: (_, _) => const SpotifyMatchingPage(),
      ),
      GoRoute(
        path: '/import-failure',
        builder: (_, _) => SpotifyImportPage(
          sessionService: SpotifyImportSessionService(
            sessionWriter: (box, values) async {
              await box.put(
                'spotifyImportTracks',
                values['spotifyImportTracks'],
              );
              throw const FileSystemException('Owned partial-write failure');
            },
          ),
        ),
      ),
    ],
  );
  NavigationManager.router = router;
  runApp(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: ThemeData(colorSchemeSeed: const Color(0xFF9B4F2A)),
    ),
  );
}

class OwnedGapHome extends StatelessWidget {
  const OwnedGapHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned acceptance rehearsal')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Scratch storage only. No provider media.'),
        const Text(String.fromEnvironment('GIT_SHA')),
        FilledButton(
          onPressed: () => context.push('/settings'),
          child: const Text('Owned settings'),
        ),
        FilledButton(
          onPressed: () => context.push('/matching'),
          child: const Text('Owned matching'),
        ),
        FilledButton(
          onPressed: () => context.push('/import-failure'),
          child: const Text('Owned failed replacement'),
        ),
      ],
    ),
  );
}
