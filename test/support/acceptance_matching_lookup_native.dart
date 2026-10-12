// Owned loopback matching acceptance. Never imported by normal startup.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/screens/spotify_matching_page.dart';
import 'package:musify/services/spotify_track_matching_service.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android rehearsal only');
  final normal = await getApplicationDocumentsDirectory();
  final scratch = Directory('${normal.path}/acceptance_lookup_v1');
  await scratch.create(recursive: true);
  Hive.init(scratch.path);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(name);
  }
  final b = Hive.box('user');
  if (!b.containsKey('lookupSeeded')) {
    await b.putAll({
      'lookupSeeded': true,
      'likedSongs': [
        {'ytid': 'lookup-retained-like'},
      ],
      'spotifyImportTracks': [
        {'sourceRow': 1, 'title': 'Owned retained row', 'artist': 'Synthetic'},
        {'sourceRow': 2, 'title': 'Owned delayed row', 'artist': 'Synthetic'},
        {
          'sourceRow': 3,
          'title': 'Owned unavailable row',
          'artist': 'Synthetic',
        },
        {'sourceRow': 4, 'title': 'Owned excluded row', 'artist': 'Synthetic'},
      ],
      'spotifyImportMetadata': {
        'importSessionId': 'owned-lookup-native',
        'matchingStatus': 'paused',
        'nextTrackIndex': 1,
      },
      'spotifyMatchResults': [
        {
          'sourceRow': 1,
          'status': 'manually_matched',
          'bestCandidate': {'ytid': 'lookup-retained-alternate'},
        },
      ],
      'spotifyExcludedImportRows': ['4'],
    });
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final client = HttpClient();
  final events = <Map<String, dynamic>>[];
  final proof = File(
    '${scratch.path}/lookup-process-${DateTime.now().microsecondsSinceEpoch}.json',
  );
  Future<void> saveProof() => proof
      .writeAsString(
        jsonEncode({
          'sourceSha': const String.fromEnvironment('GIT_SHA'),
          'loopbackOnly': true,
          'events': events,
        }),
        flush: true,
      )
      .then((_) {});
  server.listen((request) async {
    final query = request.uri.queryParameters['query'] ?? '';
    events.add({'stage': 'started', 'path': request.uri.path, 'query': query});
    await saveProof();
    try {
      if (request.uri.path == '/music' && query.contains('Owned delayed row'))
        await Future<void>.delayed(const Duration(seconds: 12));
      request.response.statusCode = query.contains('Owned unavailable row')
          ? HttpStatus.serviceUnavailable
          : HttpStatus.ok;
      request.response.write('[]');
      await request.response.close();
      events.add({
        'stage': 'completed',
        'path': request.uri.path,
        'query': query,
      });
      await saveProof();
    } catch (_) {
      events.add({'stage': 'client_interrupted', 'path': request.uri.path});
      await saveProof();
    }
  });
  Future<List<Map<String, dynamic>>> lookup(String path, String query) async {
    final request = await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', path, {'query': query}),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok)
      throw const SocketException('Owned loopback lookup unavailable');
    return (jsonDecode(body) as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  final service = SpotifyTrackMatchingService(
    musicLookup: (q) => lookup('/music', q),
    videoLookup: (q) => lookup('/video', q),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const OwnedLookupHome()),
      GoRoute(
        path: '/matching',
        builder: (_, _) => SpotifyMatchingPage(matchingService: service),
      ),
    ],
  );
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

class OwnedLookupHome extends StatelessWidget {
  const OwnedLookupHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned lookup rehearsal')),
    body: ListView(
      children: [
        const Text(String.fromEnvironment('GIT_SHA')),
        const Text('Separate synthetic storage. Emulator loopback only.'),
        FilledButton(
          onPressed: () => context.push('/matching'),
          child: const Text('Owned network matching'),
        ),
      ],
    ),
  );
}
