// Isolated native whole-playlist partial/retry acceptance. No provider requests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:musify/localization/app_localizations.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:path_provider/path_provider.dart';

final ownedPlaylistBody = List<int>.generate(8192, (i) => i % 251);
const ownedPlaylistId = 'owned-partial-playlist';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android target only');
  final normal = await getApplicationDocumentsDirectory();
  final root = Directory('${normal.path}/acceptance_playlist_boundaries_v2');
  await root.create(recursive: true);
  Hive.init(root.path);
  for (final box in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(box);
  }
  applicationDirPath = root.path;
  await FilePaths.ensureDirectoriesExist();
  if (!Hive.box('user').containsKey('ownedPlaylistSeeded')) {
    final keeper = {
      'ytid': 'owned-playlist-keeper',
      'title': 'Owned keeper',
      'audioPath': FilePaths.getAudioPath('owned-playlist-keeper'),
    };
    await File(keeper['audioPath']!).writeAsBytes([7, 8, 9], flush: true);
    await File(
      FilePaths.getAudioPath('owned-playlist-unknown'),
    ).writeAsBytes([5, 4, 3, 2], flush: true);
    await Hive.box('userNoBackup').putAll({
      'offlineSongs': [keeper],
      'offlinePlaylists': [
        {
          'ytid': 'owned-retained-playlist',
          'title': 'Owned retained playlist',
          'list': [keeper],
        },
      ],
      'ownedUnrelated': true,
    });
    await Hive.box('settings').put('ownedPreference', 'retained');
    await Hive.box('cache').put('ownedCache', {
      'keep': [1, 2, 3],
    });
    await Hive.box('user').putAll({
      'ownedPlaylistSeeded': true,
      'likedSongs': [
        {'ytid': 'owned-retained-like'},
      ],
      'ownedMemberships': ['owned-retained-membership'],
    });
  }
  userOfflineSongs.value = List<dynamic>.from(
    Hive.box('userNoBackup').get('offlineSongs'),
  );
  audioHandler = await AudioService.init(
    builder: MusifyAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.gokadzev.musify',
      androidNotificationChannelName: 'Musify',
      androidNotificationIcon: 'drawable/ic_launcher_foreground',
    ),
  );
  await audioHandler.audioPlayer.setVolume(0);
  runApp(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const OwnedPlaylistBoundaryPage(),
    ),
  );
}

class OwnedPlaylistBoundaryPage extends StatefulWidget {
  const OwnedPlaylistBoundaryPage({super.key});
  @override
  State<OwnedPlaylistBoundaryPage> createState() =>
      _OwnedPlaylistBoundaryPageState();
}

class _OwnedPlaylistBoundaryPageState extends State<OwnedPlaylistBoundaryPage> {
  String status = 'Ready';
  int loaderCalls = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(runCommand());
    });
  }

  Map<String, dynamic> playlist() => {
    'ytid': ownedPlaylistId,
    'title': 'Owned partial playlist',
    'source': 'owned_fixture',
    'list': [
      for (final id in [
        'owned-playlist-one',
        'owned-playlist-keeper',
        'owned-playlist-two',
      ])
        {'ytid': id, 'title': id, 'sourceType': 'owned_fixture'},
    ],
  };
  Future<void> proof(Map<String, dynamic> command, String stage) async {
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.box(name).flush();
    }
    final record = {
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'command': command,
      'stage': stage,
      'loaderCalls': loaderCalls,
      'playlistDownloaded': offlinePlaylistService.isPlaylistDownloaded(
        ownedPlaylistId,
      ),
      'registry': Hive.box('userNoBackup').get('offlineSongs'),
      'offlinePlaylists': Hive.box('userNoBackup').get('offlinePlaylists'),
      'completedReturnMarkers': Hive.box(
        'user',
      ).get('ownedPlaylistReturns', defaultValue: <String>[]),
      'providerRequested': false,
    };
    await File(
      '$applicationDirPath/proof-${command['nonce']}-$stage.json',
    ).writeAsString(jsonEncode(record), flush: true);
    if (mounted) setState(() => status = '$stage ${command['mode']}');
  }

  Stream<List<int>> slowBody() async* {
    for (var start = 0; start < ownedPlaylistBody.length; start += 256) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      yield ownedPlaylistBody.sublist(start, start + 256);
    }
  }

  Future<void> runCommand() async {
    final file = File('$applicationDirPath/command.json');
    if (!await file.exists()) return;
    final command = Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    final mode = command['mode'] as String, nonce = command['nonce'] as String;
    if (![
          'interrupt',
          'reopen',
          'cancel',
          'truncated',
          'retry',
          'repeat',
        ].contains(mode) ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(nonce))
      throw StateError('Invalid owned command');
    await file.rename('$applicationDirPath/consumed-$nonce.json');
    await proof(command, 'reopened');
    if (mode == 'reopen') return;
    final operation = offlinePlaylistService.downloadPlaylist(
      context,
      playlist(),
      audioLoader: (id) async {
        loaderCalls++;
        if (id == 'owned-playlist-two' && mode == 'interrupt')
          return Completer<OfflineAudioDownload?>().future;
        if (id == 'owned-playlist-two' && mode == 'cancel')
          return OfflineAudioDownload(
            slowBody(),
            expectedBytes: ownedPlaylistBody.length,
          );
        return OfflineAudioDownload(
          Stream.value(
            id == 'owned-playlist-two' && mode == 'truncated'
                ? ownedPlaylistBody.sublist(0, 16)
                : ownedPlaylistBody,
          ),
          expectedBytes: ownedPlaylistBody.length,
        );
      },
    );
    if (mode == 'interrupt' || mode == 'cancel') {
      for (var attempt = 0; attempt < 200; attempt++) {
        if (userOfflineSongs.value.any(
              (row) => row['ytid'] == 'owned-playlist-one',
            ) &&
            loaderCalls > 0)
          break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      if (!userOfflineSongs.value.any(
        (row) => row['ytid'] == 'owned-playlist-one',
      ))
        throw StateError('No owned partial registration');
      await proof(command, 'partial');
      if (mode == 'interrupt') await Completer<void>().future;
      await offlinePlaylistService.cancelDownload(context, ownedPlaylistId);
    }
    await operation;
    if (offlinePlaylistService.isPlaylistDownloaded(ownedPlaylistId)) {
      final returns = List<String>.from(
        Hive.box('user').get('ownedPlaylistReturns', defaultValue: <String>[]),
      );
      if (!returns.contains(nonce)) returns.add(nonce);
      await Hive.box('user').put('ownedPlaylistReturns', returns);
    }
    await proof(command, 'returned');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Owned playlist boundaries')),
    body: Text(status),
  );
}
