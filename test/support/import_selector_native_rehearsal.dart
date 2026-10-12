// Android-only synthetic entrypoint. Normal app Hive files are never opened.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:musify/screens/spotify_import_destination_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/spotify_import_routing_state.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android rehearsal only');
  final normal = await getApplicationDocumentsDirectory();
  final scratch = Directory('${normal.path}/i11_selector_rehearsal_v1');
  await scratch.create(recursive: true);
  Hive.init(scratch.path);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(name);
  }
  final user = Hive.box('user');
  if (!user.containsKey('spotifyImportMetadata')) {
    await user.putAll({
      'likedSongs': [
        {'ytid': 'owned-existing', 'title': 'Owned existing song'},
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'owned-i11-native-v1',
        'fileName': 'owned-i11-native.csv',
        importRoutingBaselineKey: importRoutingBaseline(
          sessionId: 'owned-i11-native-v1',
          rows: const [],
          recordedAt: '2026-10-12T00:00:00Z',
          reliable: true,
          reason: 'import_start',
        ),
      },
      'spotifyImportTracks': [
        for (var row = 1; row <= 4; row++) {'sourceRow': row},
      ],
      'spotifyMatchResults': [
        for (var row = 1; row <= 4; row++)
          {
            'sourceRow': row,
            'status': row == 4 ? 'unmatched' : 'matched',
            if (row != 4) 'bestCandidate': ownedRecording(row),
          },
      ],
    });
  }
  reloadSongLibraryStateFromStorage();
  reloadPlaylistLibraryStateFromStorage();
  runApp(
    MaterialApp(
      theme: getAppTheme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B4F2A),
          brightness: Brightness.dark,
        ),
      ),
      home: const OwnedSelectorRehearsal(),
    ),
  );
}

Map<String, dynamic> ownedRecording(int row) => {
  'ytid': row == 2 ? 'owned-alternative-2' : 'owned-recording-$row',
  'title': row == 2 ? 'Owned alternative 2' : 'Owned recording $row',
  'artist': 'Synthetic I11 fixture',
};

class OwnedSelectorRehearsal extends StatefulWidget {
  const OwnedSelectorRehearsal({super.key});
  @override
  State<OwnedSelectorRehearsal> createState() => _OwnedSelectorRehearsalState();
}

class _OwnedSelectorRehearsalState extends State<OwnedSelectorRehearsal> {
  Future<void> resolveFourth() async {
    final user = Hive.box('user');
    final rows = List<Map>.from(user.get('spotifyMatchResults'));
    rows[3] = Map.from(rows[3])
      ..['status'] = 'manually_matched'
      ..['bestCandidate'] = ownedRecording(4);
    await user.put('spotifyMatchResults', rows);
    await user.flush();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned selector rehearsal')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Synthetic scratch boxes only. No provider media.'),
        Text('Source: ${const String.fromEnvironment('GIT_SHA')}'),
        FilledButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const SpotifyImportDestinationPage(),
            ),
          ),
          child: const Text('Open owned destination'),
        ),
        FilledButton(
          onPressed: resolveFourth,
          child: const Text('Resolve owned row 4'),
        ),
        ValueListenableBuilder<List>(
          valueListenable: userLikedSongsList,
          builder: (_, songs, _) => Text('${songs.length} owned likes'),
        ),
      ],
    ),
  );
}
