// One expressly authorized, offered public muxed source. No resolver fallback.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/stream_request_context.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) throw StateError('Owned Android only');
  final normal = await getApplicationDocumentsDirectory();
  final root = Directory('${normal.path}/acceptance_public_muxed_v1');
  await root.create(recursive: true);
  Hive.init(root.path);
  for (final box in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.openBox(box);
  }
  applicationDirPath = root.path;
  await FilePaths.ensureDirectoriesExist();
  final input = Map<String, dynamic>.from(
    jsonDecode(await File('${root.path}/authorized-input.json').readAsString())
        as Map,
  );
  final url = input['url'] as String;
  final uri = Uri.parse(url);
  final id = input['videoId'] as String;
  final duration = input['durationSeconds'] as int;
  final length = input['bytes'] as int;
  final headers = StreamRequestContexts.mediaHeaders(input['producerHeaders']);
  if (headers == null ||
      !GoogleVideoByteSource.accepts(uri, length) ||
      int.tryParse(uri.queryParameters['clen'] ?? '') != length ||
      uri.queryParameters['mime'] != 'video/mp4' ||
      duration <= 0 ||
      duration > 600 ||
      length > 96 * 1024 * 1024)
    throw StateError('Invalid authorized source');
  if (sha256.convert(utf8.encode(headers['User-Agent'] ?? '')).toString() !=
      input['capturedAgentSha256'])
    throw StateError('Producer identity changed');
  if (sha256.convert(utf8.encode(url)).toString() == input['deniedUrlSha256'])
    throw StateError('Denied source replay rejected');
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
  final cache = 'song_${id}_high_url';
  await Hive.box('cache').putAll({
    cache: url,
    '${cache}_date': DateTime.now(),
    '${cache}_requestContext': {'version': 1, 'url': url, 'headers': headers},
  });
  var failed = false;
  var sourceAttempts = 0;
  final diagnostics = <Map<String, dynamic>>[];
  audioHandler = await AudioService.init(
    builder: () => MusifyAudioHandler(
      sourceFactory: (resolved, {tag, onUnavailable}) {
        if (failed || resolved != url)
          throw StateError('No alternate source or retry permitted');
        sourceAttempts++;
        return GoogleVideoByteSource(
          uri,
          sourceLength: length,
          requestHeaders: headers,
          tag: tag,
          onUnavailable: () {
            failed = true;
            unawaited(audioHandler.pause());
          },
          onDiagnostic: (event) =>
              diagnostics.add(Map<String, dynamic>.from(event)),
        );
      },
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
        body: Center(child: Text('Authorized public muxed acceptance')),
      ),
    ),
  );
  Future<void> proof(String stage, Map<String, dynamic> details) async {
    await File('${root.path}/proof-$stage.json').writeAsString(
      jsonEncode({
        'sourceSha': const String.fromEnvironment('GIT_SHA'),
        'stage': stage,
        'formatTag': input['formatTag'],
        'videoIdSha256': sha256.convert(utf8.encode(id)).toString(),
        'signedUrlSha256': sha256.convert(utf8.encode(url)).toString(),
        'expectedBytes': length,
        'durationSeconds': duration,
        'sourceAttempts': sourceAttempts,
        'positionMs': audioHandler.audioPlayer.position.inMilliseconds,
        'durationMs': audioHandler.audioPlayer.duration?.inMilliseconds,
        'processingState': audioHandler.audioPlayer.processingState.name,
        'playing': audioHandler.audioPlayer.playing,
        'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
        'diagnostics': diagnostics,
        'noCookiesCredentialsTokenModificationProxyOrIdentitySwitch': true,
        'physicalOutputVerified': false,
        ...details,
      }),
      flush: true,
    );
  }

  Future<void> waitUntil(bool Function() ready, Duration limit) async {
    final end = DateTime.now().add(limit);
    while (!ready()) {
      if (failed) throw StateError('Source denied or unavailable; stopped');
      if (DateTime.now().isAfter(end)) throw StateError('Stage deadline');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  unawaited(() async {
    try {
      final loading = audioHandler.addPlaylistToQueue(
        [
          {
            'id': id,
            'ytid': id,
            'title': 'Authorized selected recording',
            'artist': 'Public-source acceptance',
            'duration': duration,
            'image': '',
            'highResImage': '',
            'sourceType': 'youtube',
          },
        ],
        replace: true,
        startIndex: 0,
      );
      await waitUntil(
        () => audioHandler.audioPlayer.playing,
        const Duration(seconds: 20),
      );
      if ((audioHandler.audioPlayer.duration!.inSeconds - duration).abs() > 1)
        throw StateError('Provider decode duration mismatch');
      await proof('prepared', {'nativeProviderDecoded': true});
      await waitUntil(
        () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused,
        const Duration(seconds: 30),
      );
      final before = audioHandler.audioPlayer.position;
      await Future<void>.delayed(const Duration(seconds: 3));
      if (audioHandler.audioPlayer.position - before <
          const Duration(seconds: 2))
        throw StateError('Background did not advance');
      await proof('background', {'nativeProviderBackgroundAdvanced': true});
      var lastPosition = audioHandler.audioPlayer.position;
      await waitUntil(() {
        if (audioHandler.audioPlayer.position > lastPosition)
          lastPosition = audioHandler.audioPlayer.position;
        return audioHandler.audioPlayer.processingState ==
            ProcessingState.completed;
      }, Duration(seconds: duration + 30));
      if (lastPosition.inMilliseconds < (duration * 1000 - 1000))
        throw StateError('Playback ended early');
      await loading;
      await audioHandler.pause();
      await proof('complete', {
        'nativeFullProviderTrackBackground': true,
        'lastPositionMs': lastPosition.inMilliseconds,
        'noSourceFallbackOrRetry': sourceAttempts == 1,
      });
    } catch (error, stack) {
      failed = true;
      await audioHandler.pause();
      await proof('failed', {
        'errorType': error.runtimeType.toString(),
        'error': error.toString().replaceAll(
          RegExp(r'https?://\S+'),
          '[redacted-url]',
        ),
        'stack': stack.toString(),
      });
    }
  }());
}
