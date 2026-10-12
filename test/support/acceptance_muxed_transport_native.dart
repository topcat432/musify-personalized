// Owned muxed-container transport rehearsal; never loaded by normal startup.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:path_provider/path_provider.dart';

const ownedIds = ['owned-muxed', 'short-muxed'];
final diagnostics = <Map<String, dynamic>>[];

class OwnedMuxedClient extends http.BaseClient {
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.host != 'owned.test.googlevideo.com' ||
        !ownedIds.contains(request.url.queryParameters['id']) ||
        request.method != 'GET')
      throw StateError('Non-owned request rejected');
    final forwarded =
        http.Request(
            'GET',
            Uri.http(
              '127.0.0.1:8789',
              '/${request.url.queryParameters['id']}.mp4',
            ),
          )
          ..followRedirects = false
          ..headers.addAll(request.headers);
    return inner.send(forwarded);
  }

  @override
  void close() => inner.close();
}

Future<void> waitUntil(bool Function() ready, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready()) {
    if (DateTime.now().isAfter(deadline))
      throw StateError('Owned stage timed out');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android only');
  final normal = await getApplicationDocumentsDirectory();
  final root = Directory('${normal.path}/acceptance_muxed_transport_v1');
  await root.create(recursive: true);
  Hive.init(root.path);
  for (final box in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(box);
  }
  applicationDirPath = root.path;
  await FilePaths.ensureDirectoriesExist();
  await Hive.box('settings').putAll({
    'offlineMode': false,
    'wrappedEnabled': false,
    'shouldWeCheckUpdates': false,
    'sponsorBlockSupport': false,
    'externalRecommendations': false,
    'playNextSongAutomatically': false,
    'shuffleEnabled': false,
    'repeatMode': 0,
    'audioQuality': 'high',
  });
  offlineMode.value = false;
  wrappedEnabled.value = false;
  sponsorBlockSupport.value = false;
  externalRecommendations.value = false;
  playNextSongAutomatically.value = false;
  final input = Map<String, dynamic>.from(
    jsonDecode(await File('${root.path}/owned-input.json').readAsString())
        as Map,
  );
  final songs = <Map<String, dynamic>>[];
  for (var index = 0; index < 2; index++) {
    final id = ownedIds[index];
    final bytes = input[id] as int;
    if (bytes <= 0) throw StateError('Invalid owned size');
    final url = Uri.https('owned.test.googlevideo.com', '/videoplayback', {
      'id': id,
      'clen': '$bytes',
      'mime': 'video/mp4',
    }).toString();
    final key = 'song_${id}_high_url';
    await Hive.box('cache').putAll({
      key: url,
      '${key}_date': DateTime.now(),
      '${key}_requestContext': {
        'version': 1,
        'url': url,
        'headers': <String, String>{},
      },
    });
    songs.add({
      'ytid': id,
      'recordingId': 'owned-canonical-$index',
      'title': 'Owned muxed sample ${index == 0 ? 70 : 8}',
      'artist': 'Owned synthetic fixture',
      'duration': index == 0 ? 70 : 8,
      'image': '',
      'sourceType': 'owned_fixture',
    });
  }
  audioHandler = await AudioService.init(
    builder: () => MusifyAudioHandler(
      sourceFactory: (url, {tag, onUnavailable}) => GoogleVideoByteSource(
        Uri.parse(url),
        sourceLength: int.parse(Uri.parse(url).queryParameters['clen']!),
        tag: tag,
        clientFactory: OwnedMuxedClient.new,
        onUnavailable: onUnavailable,
        onDiagnostic: (event) =>
            diagnostics.add(Map<String, dynamic>.from(event)),
      ),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.gokadzev.musify',
      androidNotificationChannelName: 'Musify',
      androidNotificationIcon: 'drawable/ic_launcher_foreground',
    ),
  );
  await audioHandler.audioPlayer.setVolume(0);
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Owned muxed transport acceptance')),
      ),
    ),
  );
  unawaited(runOwnedAcceptance(root, songs));
}

Future<void> runOwnedAcceptance(
  Directory root,
  List<Map<String, dynamic>> songs,
) async {
  Future<void> proof(String stage, Map<String, dynamic> details) async {
    await File('${root.path}/proof-$stage.json').writeAsString(
      jsonEncode({
        'sourceSha': const String.fromEnvironment('GIT_SHA'),
        'stage': stage,
        'providerRequested': false,
        'physicalOutputVerified': false,
        'currentIndex': audioHandler.audioPlayer.currentIndex,
        'positionMs': audioHandler.audioPlayer.position.inMilliseconds,
        'durationMs': audioHandler.audioPlayer.duration?.inMilliseconds,
        'playing': audioHandler.audioPlayer.playing,
        'processingState': audioHandler.audioPlayer.processingState.name,
        'loopMode': audioHandler.audioPlayer.loopMode.name,
        'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
        'queueIds': audioHandler.queue.value.map((item) => item.id).toList(),
        'diagnostics': diagnostics,
        ...details,
      }),
      flush: true,
    );
  }

  try {
    final loading = audioHandler.addPlaylistToQueue(
      songs,
      replace: true,
      startIndex: 0,
    );
    await waitUntil(
      () => audioHandler.audioPlayer.playing,
      const Duration(seconds: 15),
    );
    if ((audioHandler.audioPlayer.duration!.inMilliseconds - 70000).abs() > 500)
      throw StateError('Muxed 70 duration mismatch');
    await proof('prepared', {'ownedMuxedDecoded': true});
    await waitUntil(
      () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused,
      const Duration(seconds: 20),
    );
    final before = audioHandler.audioPlayer.position;
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!audioHandler.audioPlayer.playing ||
        audioHandler.audioPlayer.position - before < const Duration(seconds: 2))
      throw StateError('Background playback did not advance');
    await proof('background', {'backgroundAdvanced': true});
    var firstTail = false;
    await waitUntil(() {
      if (audioHandler.audioPlayer.currentIndex == 0 &&
          audioHandler.audioPlayer.position >=
              const Duration(milliseconds: 69500))
        firstTail = true;
      return audioHandler.audioPlayer.currentIndex == 1 ||
          audioHandler.audioPlayer.processingState == ProcessingState.completed;
    }, const Duration(seconds: 85));
    if (audioHandler.audioPlayer.currentIndex == 0) {
      firstTail = true;
      await audioHandler.skipToNext();
    }
    await waitUntil(
      () =>
          audioHandler.audioPlayer.currentIndex == 1 &&
          audioHandler.audioPlayer.playing,
      const Duration(seconds: 15),
    );
    if ((audioHandler.audioPlayer.duration!.inMilliseconds - 8000).abs() > 500)
      throw StateError('Muxed 8 duration mismatch');
    await proof('continuous-next', {
      'firstUninterruptedTailObserved': firstTail,
      'secondDecoded': true,
    });
    await waitUntil(
      () =>
          audioHandler.audioPlayer.processingState ==
              ProcessingState.completed ||
          !audioHandler.audioPlayer.playing,
      const Duration(seconds: 15),
    );
    await loading;
    await proof('continuous-complete', {'twoMuxedTracksContinuous': true});
    final replay = audioHandler.addPlaylistToQueue(
      songs,
      replace: true,
      startIndex: 0,
    );
    await waitUntil(
      () =>
          audioHandler.audioPlayer.currentIndex == 0 &&
          audioHandler.audioPlayer.playing,
      const Duration(seconds: 15),
    );
    await audioHandler.seek(const Duration(seconds: 35));
    await waitUntil(
      () => audioHandler.audioPlayer.position >= const Duration(seconds: 34),
      const Duration(seconds: 10),
    );
    await proof('seek-middle', {'middleSeek': true});
    await audioHandler.seek(const Duration(seconds: 69));
    await waitUntil(
      () =>
          audioHandler.audioPlayer.position >= const Duration(seconds: 68) ||
          audioHandler.audioPlayer.currentIndex == 1,
      const Duration(seconds: 10),
    );
    await proof('seek-tail', {'tailSeek': true});
    if (audioHandler.audioPlayer.currentIndex == 0)
      await audioHandler.skipToNext();
    await waitUntil(
      () =>
          audioHandler.audioPlayer.currentIndex == 1 &&
          audioHandler.audioPlayer.playing,
      const Duration(seconds: 15),
    );
    await audioHandler.pause();
    await replay;
    await proof('complete', {
      'continuousBackground70And8': true,
      'middleTailNext': true,
      'originalRecordingMaps': songs,
    });
  } catch (error, stack) {
    await audioHandler.pause();
    await proof('failed', {
      'errorType': error.runtimeType.toString(),
      'error': error.toString(),
      'stack': stack.toString(),
    });
  }
}
