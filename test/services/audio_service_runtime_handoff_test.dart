import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musify/models/playback_source_info.dart';
import 'package:musify/services/stream_request_context.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart'
    show songStreamUrlCacheKey, userOfflineSongs;
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/online_audio_source.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('runtime-handoff-');
    Hive.init(directory.path);
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.openBox(name);
    }
  });

  for (final online in [false, true]) {
    for (final registered in [false, true]) {
      for (final kind in ['missing', 'empty', 'short', 'tampered']) {
        test(
          '$kind ${registered ? 'registered' : 'passed'} audio cannot reach native or online source, online=$online',
          () async {
            offlineMode.value = !online;
            sponsorBlockSupport.value = false;
            playNextSongAutomatically.value = false;
            final id = 'integrity-$online-$registered-$kind';
            final file = File('${directory.path}/$id.m4a');
            if (kind != 'missing')
              await file.writeAsBytes(
                kind == 'empty'
                    ? []
                    : kind == 'short'
                    ? [1]
                    : [9, 9, 9, 9],
                flush: true,
              );
            final entry = <String, dynamic>{
              'ytid': id,
              'title': 'Synthetic saved audio',
              'highResImage': '',
              'audioPath': file.path,
              'offlineAudioBytes': 4,
              'offlineAudioSha256': sha256.convert([1, 2, 3, 4]).toString(),
            };
            final registry = registered ? [entry] : <Map<String, dynamic>>[];
            await Hive.box('userNoBackup').put('offlineSongs', registry);
            userOfflineSongs.value = registry;
            var sources = 0;
            final player = _PendingPlayer();
            final handler = MusifyAudioHandler(
              player: player,
              sourceFactory: (url, {tag, onUnavailable}) {
                sources++;
                throw StateError('Synthetic guard: no online source permitted');
              },
            );
            try {
              final passed = {...entry};
              if (registered) {
                final stale = File('${directory.path}/$id-stale.m4a');
                await stale.writeAsBytes([1, 2, 3, 4], flush: true);
                passed['audioPath'] = stale.path;
              }
              expect(await handler.playSong(passed), isFalse);
              expect(sources, 0);
              expect(player.loadedIds, isEmpty);
              expect(Hive.box('userNoBackup').get('offlineSongs'), registry);
              expect(
                await file.exists() ? await file.readAsBytes() : null,
                kind == 'missing'
                    ? null
                    : kind == 'empty'
                    ? []
                    : kind == 'short'
                    ? [1]
                    : [9, 9, 9, 9],
              );
            } finally {
              await handler.stop();
              await player.dispose();
              await Hive.box('userNoBackup').put('offlineSongs', []);
              userOfflineSongs.value = [];
              offlineMode.value = false;
            }
          },
        );
      }
    }
  }

  test(
    'late native cancellation error after Stop cannot restart the queue',
    () async {
      offlineMode.value = true;
      sponsorBlockSupport.value = false;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/late-stop-error.wav')
        ..writeAsBytesSync([0]);
      final player = _PendingPlayer();
      final handler = MusifyAudioHandler(player: player);
      Map<String, dynamic> song(String name) => {
        'ytid': name,
        'title': name,
        'audioPath': file.path,
        'highResImage': '',
      };
      try {
        await handler.addPlaylistToQueue(
          [song('Stopped'), song('Next')],
          replace: true,
          startIndex: 0,
        );
        await handler.stop();
        player.errors.add(
          PlayerException(0, 'Owned late cancellation callback', 0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 2300));
        expect(player.loadedIds, ['Stopped']);
        expect(player.playing, isFalse);
        expect(handler.playbackState.value.errorMessage, isNull);
        expect(handler.activeSource.value, isNull);
        await handler.play();
        expect(player.playing, isTrue);
        expect(handler.activeSource.value?.kind, PlaybackSourceKind.local);
      } finally {
        await handler.stop();
        await player.dispose();
        offlineMode.value = false;
      }
    },
  );

  test(
    'an old native failure finishing after Stop and explicit Play cannot own the replay',
    () async {
      offlineMode.value = true;
      sponsorBlockSupport.value = false;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/pending-stop-replay.wav')
        ..writeAsBytesSync([0]);
      final player = _DelayedPausePlayer();
      final handler = MusifyAudioHandler(player: player);
      Map<String, dynamic> song(String name) => {
        'ytid': name,
        'title': name,
        'audioPath': file.path,
        'highResImage': '',
      };
      try {
        await handler.addPlaylistToQueue(
          [song('Replay'), song('Next')],
          replace: true,
          startIndex: 0,
        );
        final oldFailure = handler.handleRuntimePlaybackError(
          PlayerException(0, 'Owned old event', 0),
        );
        await player.pauseStarted.future;
        await handler.stop();
        await handler.play();
        expect(player.playing, isTrue);
        expect(player.stopCalls, 1);
        expect(player.loadedIds, ['Replay']);
        expect(handler.playbackState.value.errorMessage, isNull);
        expect(handler.activeSource.value?.kind, PlaybackSourceKind.local);
        // The newer playback still owns a real current error: stale ownership
        // suppression must not hide failures after replay becomes active.
        await handler.handleRuntimePlaybackError(
          PlayerException(0, 'Owned current event', 0),
        );
        expect(player.playing, isFalse);
        expect(player.stopCalls, 2);
        expect(handler.playbackState.value.errorMessage, isNotNull);
        player.finishPause.complete();
        await oldFailure;
        // Completing the old handler cannot undo or duplicate the newer error.
        expect(player.playing, isFalse);
        expect(player.stopCalls, 2);
        await handler.handleRuntimePlaybackError(
          PlayerException(0, 'Owned duplicate current event', 0),
        );
        expect(player.stopCalls, 2);
      } finally {
        if (!player.finishPause.isCompleted) player.finishPause.complete();
        await handler.stop();
        await player.dispose();
        offlineMode.value = false;
      }
    },
  );

  for (final online in [false, true]) {
    test('healthy ${online ? 'online' : 'local'} Stop then Play restores '
        'source ownership and attribution', () async {
      offlineMode.value = !online;
      sponsorBlockSupport.value = false;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/stopped-replay.wav')
        ..writeAsBytesSync([0]);
      const id = 'owned-stop-replay';
      const url =
          'https://fixture.googlevideo.com/audio?mime=audio/webm&clen=10';
      streamRequestContexts.remember(url, {
        'User-Agent': 'Owned fixture',
      }, sourceLength: 10);
      final key = songStreamUrlCacheKey(id);
      await Hive.box('cache').putAll({
        key: url,
        '${key}_date': DateTime.now(),
        '${key}_requestContext': streamRequestContexts.snapshot(url),
      });
      final sources = <GoogleVideoByteSource>[];
      final unavailableCallbacks = <void Function()>[];
      var requests = 0;
      final player = _PendingPlayer();
      final handler = MusifyAudioHandler(
        player: player,
        sourceFactory: (location, {tag, onUnavailable}) {
          if (onUnavailable != null) unavailableCallbacks.add(onUnavailable);
          final source = GoogleVideoByteSource(
            Uri.parse(location),
            sourceLength: 10,
            tag: tag,
            onUnavailable: onUnavailable,
            clientFactory: () => MockClient((request) async {
              requests++;
              return http.Response.bytes(
                List.filled(10, 7),
                206,
                headers: {
                  'content-length': '10',
                  'content-range': 'bytes 0-9/10',
                },
              );
            }),
          );
          sources.add(source);
          return source;
        },
      );
      try {
        await handler.addPlaylistToQueue(
          [
            {
              'ytid': id,
              'title': 'Healthy',
              'highResImage': '',
              if (!online) 'audioPath': file.path,
            },
          ],
          replace: true,
          startIndex: 0,
        );
        final firstSource = player.audioSource;
        await handler.stop();
        expect(handler.activeSource.value, isNull);
        if (online) {
          await expectLater(sources.first.request(), throwsStateError);
        }
        await handler.play();
        expect(player.playing, isTrue);
        expect(
          handler.activeSource.value?.kind,
          online ? PlaybackSourceKind.youtube : PlaybackSourceKind.local,
        );
        expect(handler.currentSong!['ytid'], id);
        expect(handler.queue.value.length, 1);
        if (online) {
          expect(sources.length, 2);
          expect(player.audioSource, isNot(same(firstSource)));
          unavailableCallbacks.first();
          await Future<void>.delayed(Duration.zero);
          expect(player.playing, isTrue);
          expect(player.loadedIds, ['Healthy', 'Healthy']);
          expect(handler.playbackState.value.errorMessage, isNull);
          final response = await sources.last.request();
          expect(
            await response.stream.fold<int>(
              0,
              (sum, bytes) => sum + bytes.length,
            ),
            10,
          );
          await expectLater(sources.first.request(), throwsStateError);
          expect(requests, 1);
        } else {
          expect(player.audioSource, same(firstSource));
          expect(player.loadedIds, ['Healthy']);
          expect(requests, 0);
        }
      } finally {
        await handler.stop();
        await player.dispose();
        offlineMode.value = false;
      }
    });
  }

  for (final fails in [false, true]) {
    test('superseded initial native ${fails ? 'failure' : 'success'} preserves '
        'the chosen source without stale recovery', () async {
      offlineMode.value = false;
      sponsorBlockSupport.value = false;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/late-load.wav')
        ..writeAsBytesSync([0]);
      final key = songStreamUrlCacheKey('owned-old-load');
      await Hive.box('cache').putAll({
        key: 'https://owned.invalid/stale-recovery',
        '${key}_date': DateTime.now(),
      });
      final player = _DelayedFirstLoadPlayer();
      var staleRecoveries = 0;
      final handler = MusifyAudioHandler(
        player: player,
        sourceFactory: (url, {tag, onUnavailable}) {
          staleRecoveries++;
          return AudioSource.file(file.path, tag: tag);
        },
      );
      Map<String, dynamic> song(String id, String title) => {
        'ytid': id,
        'title': title,
        'audioPath': file.path,
        'highResImage': '',
      };
      try {
        final oldLoad = handler.addPlaylistToQueue(
          [song('owned-old-load', 'Old'), song('owned-chosen', 'Chosen')],
          replace: true,
          startIndex: 0,
        );
        await player.firstLoadStarted.future;
        await handler.skipToQueueItem(1);
        expect(player.playing, isTrue);
        final chosenSource = player.audioSource;
        if (fails) {
          player.finishFirstLoad.completeError(
            PlayerException(0, 'Owned superseded load failure', 0),
          );
        } else {
          player.finishFirstLoad.complete();
        }
        await oldLoad;
        await Future<void>.delayed(Duration.zero);
        expect(player.stopCalls, 0);
        expect(player.playing, isTrue);
        expect(player.audioSource, same(chosenSource));
        expect(handler.currentSong!['title'], 'Chosen');
        expect(handler.playbackState.value.errorMessage, isNull);
        expect(staleRecoveries, 0);
      } finally {
        if (!player.finishFirstLoad.isCompleted) {
          player.finishFirstLoad.complete();
        }
        await handler.stop();
        await player.dispose();
      }
    });
  }

  test('a new paused Now Playing subscriber gets current position and duration '
      'without waiting for resumed playback', () async {
    final player = _SnapshotPlayer();
    final handler = MusifyAudioHandler(player: player);
    final first = handler.positionDataStream.listen((_) {});
    try {
      await handler.positionDataStream.first.timeout(
        const Duration(milliseconds: 200),
      );
      player.positions.add(const Duration(seconds: 9));
      await Future<void>.delayed(Duration.zero);
      final lateSnapshot = await handler.positionDataStream.first.timeout(
        const Duration(milliseconds: 200),
      );
      expect(player.playing, isFalse);
      expect(lateSnapshot.position, const Duration(seconds: 9));
      expect(lateSnapshot.duration, const Duration(seconds: 45));
      player.positions.add(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final zero = await handler.positionDataStream.first.timeout(
        const Duration(milliseconds: 200),
      );
      expect(zero.position, Duration.zero);
      expect(zero.duration, const Duration(seconds: 45));
    } finally {
      await first.cancel();
      await handler.stop();
      await player.dispose();
    }
  });

  test(
    'offline mode rejects unsaved queue items before cached online resolution',
    () async {
      offlineMode.value = true;
      sponsorBlockSupport.value = false;
      final owned = File('${directory.path}/owned-cache-source.wav')
        ..writeAsBytesSync([0]);
      for (final missingPath in [false, true]) {
        final id = 'owned-offline-missing-$missingPath';
        final key = songStreamUrlCacheKey(id);
        const location = 'https://owned.invalid/synthetic-audio';
        await Hive.box(
          'cache',
        ).putAll({key: location, '${key}_date': DateTime.now()});
        final player = _PendingPlayer();
        var onlineSources = 0;
        final handler = MusifyAudioHandler(
          player: player,
          sourceFactory: (url, {tag, onUnavailable}) {
            onlineSources++;
            return AudioSource.file(owned.path, tag: tag);
          },
        );
        try {
          final result = await handler.playSong({
            'ytid': id,
            'title': 'Missing saved fixture',
            'highResImage': '',
            if (missingPath) 'audioPath': '${directory.path}/not-present.wav',
          });
          expect(result, isFalse);
          expect(onlineSources, 0);
          expect(player.loadedIds, isEmpty);
          expect(player.playing, isFalse);
          expect(Hive.box('cache').get(key), location);
        } finally {
          await handler.stop();
          await player.dispose();
        }
      }
      offlineMode.value = false;
    },
  );

  test('Replay after healthy completion seeks zero and resumes without waiting '
      'for the playback lifetime or reloading the source', () async {
    offlineMode.value = true;
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
    final file = File('${directory.path}/replay-fixture.wav')
      ..writeAsBytesSync([0]);
    final player = _ReplayPlayer();
    final handler = MusifyAudioHandler(player: player);
    try {
      await handler.addPlaylistToQueue(
        [
          {
            'ytid': 'healthy-replay',
            'title': 'Healthy Replay',
            'audioPath': file.path,
            'highResImage': '',
          },
        ],
        replace: true,
        startIndex: 0,
      );
      await handler.handleSongCompletion();
      expect(player.playing, isFalse);
      await handler.playAgain().timeout(const Duration(milliseconds: 200));
      expect(player.seeks, [Duration.zero]);
      expect(player.playing, isTrue);
      expect(player.pendingPlay!.isCompleted, isFalse);
      expect(player.loadedIds, ['Healthy Replay']);
      expect(handler.queue.value.length, 1);
    } finally {
      await handler.stop();
      await player.dispose();
      offlineMode.value = false;
    }
  });

  test('bounded source failure stops and reports within one second, without '
      'another native or upstream attempt', () async {
    offlineMode.value = true;
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
    final file = File('${directory.path}/denied-fixture.wav')
      ..writeAsBytesSync([0]);
    final client = _DeniedClient();
    final player = _ByteReadingPlayer();
    final handler = _ByteFixtureHandler(
      player,
      (url, {tag, onUnavailable}) => GoogleVideoByteSource(
        Uri.parse(url),
        sourceLength: 10,
        tag: tag,
        onUnavailable: onUnavailable,
        clientFactory: () => client,
      ),
    );
    try {
      final elapsed = Stopwatch()..start();
      final miniPlayerError = handler.playbackStateStream.firstWhere(
        (state) => state.errorMessage != null,
      );
      await handler.addPlaylistToQueue(
        [
          {
            'ytid': 'denied',
            'title': 'Denied',
            'audioPath': file.path,
            'highResImage': '',
          },
        ],
        replace: true,
        startIndex: 0,
      );
      await handler.playbackState
          .firstWhere((state) => state.errorMessage != null)
          .timeout(const Duration(seconds: 1));
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 1)));
      expect(player.playing, isFalse);
      expect(player.pauseCalls, 1);
      expect(player.stopCalls, 1);
      expect(
        (await miniPlayerError.timeout(
          const Duration(seconds: 1),
        )).errorMessage,
        contains('Choose another recording'),
      );
      expect(
        handler.playbackState.value.errorMessage,
        contains('Choose another recording'),
      );
      await handler.play();
      await handler.playAgain();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(client.requests, 1);
      expect(client.closes, 1);
      expect(player.loadedIds, ['Denied']);
    } finally {
      await handler.stop();
      await player.dispose();
      offlineMode.value = false;
    }
  });

  test('repeat all stops after three runtime failures instead of wrapping '
      'through denied sources again', () async {
    offlineMode.value = true;
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.all;
    final file = File('${directory.path}/repeat-failure.wav')
      ..writeAsBytesSync([0]);
    final clients = <_DeniedClient>[];
    final player = _ByteReadingPlayer();
    final handler = _ByteFixtureHandler(player, (url, {tag, onUnavailable}) {
      final client = _DeniedClient();
      clients.add(client);
      return GoogleVideoByteSource(
        Uri.parse(url),
        sourceLength: 10,
        tag: tag,
        onUnavailable: onUnavailable,
        clientFactory: () => client,
      );
    });
    try {
      await handler.addPlaylistToQueue(
        [
          for (var i = 1; i <= 3; i++)
            {
              'ytid': 'denied-$i',
              'title': 'Denied $i',
              'audioPath': file.path,
              'highResImage': '',
            },
        ],
        replace: true,
        startIndex: 0,
      );
      await Future<void>.delayed(const Duration(seconds: 7));
      expect(player.loadedIds, ['Denied 1', 'Denied 2', 'Denied 3']);
      expect(clients.length, 3);
      expect(clients.every((client) => client.requests == 1), isTrue);
      expect(player.playing, isFalse);
      expect(handler.queue.value.length, 3);
      expect(handler.playbackState.value.errorMessage, isNotNull);
    } finally {
      await handler.stop();
      await player.dispose();
      offlineMode.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
    }
  });
  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test(
    'Stop cancels a pending source header read promptly without queue retry',
    () async {
      offlineMode.value = true;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/stalled.wav')..writeAsBytesSync([0]);
      final client = _StalledClient();
      final player = _LoadingPlayer();
      final handler = _ByteFixtureHandler(
        player,
        (url, {tag, onUnavailable}) => GoogleVideoByteSource(
          Uri.parse(url),
          sourceLength: 10,
          tag: tag,
          onUnavailable: onUnavailable,
          clientFactory: () => client,
        ),
      );
      try {
        final operation = handler.addPlaylistToQueue(
          [
            {
              'ytid': 'stalled',
              'title': 'Stalled',
              'audioPath': file.path,
              'highResImage': '',
            },
          ],
          replace: true,
          startIndex: 0,
        );
        await client.started.future;
        await handler.stop().timeout(const Duration(milliseconds: 500));
        await operation.timeout(const Duration(milliseconds: 500));
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(client.closes, 1);
        expect(client.requests, 1);
        expect(player.loadedIds, ['Stalled']);
        expect(player.playing, isFalse);
        expect(handler.playbackState.value.errorMessage, isNull);
      } finally {
        await handler.stop();
        await player.dispose();
        offlineMode.value = false;
      }
    },
  );

  test(
    'new selection during error pause is never stopped by the old failure',
    () async {
      offlineMode.value = true;
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      final file = File('${directory.path}/selection.wav')
        ..writeAsBytesSync([0]);
      final player = _DelayedPausePlayer();
      final handler = MusifyAudioHandler(player: player);
      Map<String, dynamic> song(String title) => {
        'ytid': title,
        'title': title,
        'audioPath': file.path,
        'highResImage': '',
      };
      try {
        await handler.addPlaylistToQueue(
          [song('First'), song('Chosen')],
          replace: true,
          startIndex: 0,
        );
        player.errors.add(PlayerException(403, 'fixture failed', 0));
        await player.pauseStarted.future;
        await handler.skipToQueueItem(1);
        player.finishPause.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(player.loadedIds, ['First', 'Chosen']);
        expect(player.playing, isTrue);
        expect(player.stopCalls, 0);
        expect(handler.playbackState.value.errorMessage, isNull);
      } finally {
        if (!player.finishPause.isCompleted) player.finishPause.complete();
        await handler.stop();
        await player.dispose();
        offlineMode.value = false;
      }
    },
  );

  test('real load handoff releases loading while play is pending, then '
      'native errorStream pauses and advances once', () async {
    offlineMode.value = true;
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
    final file = File('${directory.path}/fixture.wav')..writeAsBytesSync([0]);
    final player = _PendingPlayer();
    final handler = MusifyAudioHandler(player: player);
    Map<String, dynamic> song(String id) => {
      'ytid': id,
      'title': id,
      'audioPath': file.path,
      'highResImage': '',
    };
    try {
      final operation = handler.addPlaylistToQueue(
        [song('first'), song('next')],
        replace: true,
        startIndex: 0,
      );
      await player.started.future.timeout(const Duration(seconds: 2));
      // A real just_audio play future is deliberately still pending here.
      expect(player.pendingPlay!.isCompleted, isFalse);
      await operation.timeout(const Duration(seconds: 1));
      expect(
        (Hive.box('user').get('recentlyPlayedSongs') as List).map(
          (item) => item['ytid'],
        ),
        contains('first'),
      );
      player.errors.add(PlayerException(403, 'fixture source failed', 0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The native stream and play future can report the same failure at
      // different times, after the first pause has already completed.
      player.errors.add(PlayerException(403, 'same fixture failure', 0));
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(player.pauseCalls, 1);
      expect(player.loadedIds, ['first', 'next']);
      expect(handler.currentSong!['ytid'], 'next');
      expect(player.pendingPlay!.isCompleted, isFalse);
    } finally {
      await handler.stop();
      await player.dispose();
      offlineMode.value = false;
    }
  });
}

class _PendingPlayer extends AudioPlayer {
  _PendingPlayer() : super(handleAudioSessionActivation: false);
  final errors = StreamController<PlayerException>.broadcast();
  final started = Completer<void>();
  final loadedIds = <String>[];
  Completer<void>? pendingPlay;
  AudioSource? source;
  bool active = false;
  int pauseCalls = 0;
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  bool get playing => active;
  @override
  AudioSource? get audioSource => source;
  @override
  Duration? get duration => const Duration(seconds: 30);
  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = audioSource;
    loadedIds.add((audioSource as IndexedAudioSource).tag.title as String);
    return duration;
  }

  @override
  Future<void> play() {
    active = true;
    pendingPlay = Completer<void>();
    if (!started.isCompleted) started.complete();
    return pendingPlay!.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    active = false;
    if (pendingPlay != null && !pendingPlay!.isCompleted)
      pendingPlay!.complete();
  }

  @override
  Future<void> stop() async {
    active = false;
    if (pendingPlay != null && !pendingPlay!.isCompleted)
      pendingPlay!.complete();
  }

  @override
  Future<void> dispose() async {
    await errors.close();
    await super.dispose();
  }
}

class _DelayedFirstLoadPlayer extends _PendingPlayer {
  final firstLoadStarted = Completer<void>();
  final finishFirstLoad = Completer<void>();
  int stopCalls = 0;

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    await super.setAudioSource(
      audioSource,
      preload: preload,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    if (loadedIds.last == 'Old') {
      firstLoadStarted.complete();
      await finishFirstLoad.future;
    }
    return duration;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

class _ReplayPlayer extends _PendingPlayer {
  final seeks = <Duration>[];
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position!);
  }
}

class _SnapshotPlayer extends _PendingPlayer {
  final positions = BehaviorSubject<Duration>.seeded(Duration.zero);
  final buffered = BehaviorSubject<Duration>.seeded(
    const Duration(seconds: 45),
  );
  final durations = BehaviorSubject<Duration?>.seeded(
    const Duration(seconds: 45),
  );
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration> get bufferedPositionStream => buffered.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Future<void> dispose() async {
    await positions.close();
    await buffered.close();
    await durations.close();
    await super.dispose();
  }
}

class _DeniedClient extends http.BaseClient {
  int requests = 0;
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(const Stream.empty(), 403);
  }

  @override
  void close() {
    closes++;
  }
}

class _ByteFixtureHandler extends MusifyAudioHandler {
  _ByteFixtureHandler(AudioPlayer player, OnlineSourceFactory factory)
    : super(player: player, sourceFactory: factory);
  @override
  Future<AudioSource?> buildAudioSource(Map song, String url, bool offline) =>
      super.buildAudioSource(
        song,
        'https://fixture.googlevideo.com/audio?clen=10',
        false,
      );
}

class _ByteReadingPlayer extends _PendingPlayer {
  int stopCalls = 0;
  @override
  Future<void> play() {
    final completion = super.play();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 10), () async {
        final streamSource = audioSource as StreamAudioSource;
        try {
          await (await streamSource.request()).stream.drain<void>();
        } catch (_) {}
      }),
    );
    return completion;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}

class _StalledClient extends http.BaseClient {
  final started = Completer<void>();
  final pending = Completer<http.StreamedResponse>();
  int requests = 0;
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    started.complete();
    return pending.future;
  }

  @override
  void close() {
    closes++;
    if (!pending.isCompleted)
      pending.completeError(StateError('fixture cancelled'));
  }
}

class _LoadingPlayer extends _PendingPlayer {
  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    await super.setAudioSource(
      source,
      preload: preload,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    await (await (source as StreamAudioSource).request()).stream.drain<void>();
    return duration;
  }
}

class _DelayedPausePlayer extends _PendingPlayer {
  final pauseStarted = Completer<void>();
  final finishPause = Completer<void>();
  int stopCalls = 0;
  @override
  Future<void> pause() async {
    if (!pauseStarted.isCompleted) {
      pauseStarted.complete();
      await finishPause.future;
      return;
    }
    await super.pause();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await super.stop();
  }
}
