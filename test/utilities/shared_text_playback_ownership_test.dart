import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/common_services.dart' show userRecentlyPlayed;
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/sharing_intent.dart';

final _testPlayers = <_OwnedPlayer>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File audio;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('shared-text-owner-');
    Hive.init(directory.path);
    for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
      await Hive.openBox(name);
    }
    audio = File('${directory.path}/synthetic.wav')..writeAsBytesSync([0]);
    offlineMode.value = true;
    sponsorBlockSupport.value = false;
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
  });

  setUp(() async {
    _testPlayers.clear();
    userRecentlyPlayed.value = [];
    await Hive.box('user').put('recentlyPlayedSongs', []);
  });

  tearDown(() async {
    await Hive.box('user').flush();
    final expected = _testPlayers
        .expand((player) => player.playedIds)
        .toList()
        .reversed
        .toSet()
        .toList();
    expect(
      userRecentlyPlayed.value.map((song) => song['ytid']).toList(),
      expected,
      reason: 'Recent history must attribute only recordings actually played',
    );
    expect(
      (Hive.box('user').get('recentlyPlayedSongs') as List)
          .map((song) => song['ytid'])
          .toList(),
      expected,
      reason: 'Persisted history must not attribute stale source completions',
    );
  });

  void expectSelection(MusifyAudioHandler handler, String winner) {
    expect(handler.currentSong?['ytid'], winner);
    expect(handler.mediaItem.value?.title, winner);
    expect(handler.queue.value.map((item) => item.title).toList(), [winner]);
  }

  Map song(String id) => {
    'ytid': id,
    'title': id,
    'audioPath': audio.path,
    'highResImage': '',
  };

  const a = 'AAAAAAAAAAA';
  const b = 'BBBBBBBBBBB';

  test('initial metadata A cannot replace newer warm share B', () async {
    final player = _OwnedPlayer();
    final handler = _SourceGateHandler(player);
    final pendingA = Completer<Map>();
    final resolvingA = Completer<void>();
    var generation = 0;
    final old = consumeInitialSharedTextIntent(
      readInitialText: () async => 'https://youtu.be/$a',
      stillCurrent: () => generation == 0,
      consume: (value) => consumeYoutubeSharedTextIntent(
        value,
        audioHandler: handler,
        stillCurrent: () => generation == 0,
        resolveSong: (_) {
          resolvingA.complete();
          return pendingA.future;
        },
        onError: (error, stack) => fail('$error'),
      ),
      onError: (error, stack) => fail('$error'),
    );
    try {
      await resolvingA.future;
      generation++;
      await consumeYoutubeSharedTextIntent(
        'https://youtu.be/$b',
        audioHandler: handler,
        stillCurrent: () => generation == 1,
        resolveSong: (_) async => song(b),
        onError: (error, stack) => fail('$error'),
      );
      pendingA.complete(song(a));
      await old;
      expect(player.loadedIds, [b]);
      expect(player.playedIds, [b]);
      expectSelection(handler, b);
    } finally {
      if (!pendingA.isCompleted) pendingA.complete(song(a));
      await old;
      await handler.stop();
      await player.dispose();
    }
  });

  test('disposal after initial read cancels pending metadata', () async {
    final player = _OwnedPlayer();
    final handler = _SourceGateHandler(player);
    final pending = Completer<Map>();
    final resolving = Completer<void>();
    var mounted = true;
    final request = consumeInitialSharedTextIntent(
      readInitialText: () async => 'https://youtu.be/$a',
      stillCurrent: () => mounted,
      consume: (value) => consumeYoutubeSharedTextIntent(
        value,
        audioHandler: handler,
        stillCurrent: () => mounted,
        resolveSong: (_) {
          resolving.complete();
          return pending.future;
        },
        onError: (error, stack) => fail('$error'),
      ),
      onError: (error, stack) => fail('$error'),
    );
    try {
      await resolving.future;
      mounted = false;
      pending.complete(song(a));
      await request;
      expect(player.loadedIds, isEmpty);
      expect(player.playedIds, isEmpty);
    } finally {
      if (!pending.isCompleted) pending.complete(song(a));
      await request;
      await handler.stop();
      await player.dispose();
    }
  });

  for (final dispose in [false, true]) {
    test(
      'pending playback A yields to ${dispose ? 'disposal' : 'warm B'}',
      () async {
        final player = _OwnedPlayer();
        final handler = _SourceGateHandler(player)..gateA = true;
        var generation = 0;
        final old = consumeYoutubeSharedTextIntent(
          'https://youtu.be/$a',
          audioHandler: handler,
          stillCurrent: () => generation == 0,
          resolveSong: (_) async => song(a),
          onError: (error, stack) => fail('$error'),
        );
        try {
          await handler.sourceStarted.future;
          generation++;
          if (!dispose) {
            await consumeYoutubeSharedTextIntent(
              'https://youtu.be/$b',
              audioHandler: handler,
              stillCurrent: () => generation == 1,
              resolveSong: (_) async => song(b),
              onError: (error, stack) => fail('$error'),
            );
          }
          handler.releaseSource.complete();
          await old;
          expect(player.loadedIds, dispose ? isEmpty : [b]);
          expect(player.playedIds, dispose ? isEmpty : [b]);
          if (!dispose) expectSelection(handler, b);
        } finally {
          if (!handler.releaseSource.isCompleted)
            handler.releaseSource.complete();
          await old;
          await handler.stop();
          await player.dispose();
        }
      },
    );
  }

  test('native source load A finishing after B cannot play B again', () async {
    final player = _OwnedPlayer()..gateNativeA = true;
    final handler = _SourceGateHandler(player);
    var generation = 0;
    final old = consumeYoutubeSharedTextIntent(
      'https://youtu.be/$a',
      audioHandler: handler,
      stillCurrent: () => generation == 0,
      resolveSong: (_) async => song(a),
      onError: (error, stack) => fail('$error'),
    );
    try {
      await player.nativeStarted.future;
      generation++;
      await consumeYoutubeSharedTextIntent(
        'https://youtu.be/$b',
        audioHandler: handler,
        stillCurrent: () => generation == 1,
        resolveSong: (_) async => song(b),
        onError: (error, stack) => fail('$error'),
      );
      player.releaseNative.complete();
      await old;
      expect(player.playedIds, [b]);
      expect(player.playing, isTrue);
      expectSelection(handler, b);
    } finally {
      if (!player.releaseNative.isCompleted) player.releaseNative.complete();
      await old;
      await handler.stop();
      await player.dispose();
    }
  });

  for (final stop in [false, true]) {
    test(
      'cold metadata A yields to normal ${stop ? 'Stop' : 'queue B'}',
      () async {
        final player = _OwnedPlayer();
        final handler = _SourceGateHandler(player);
        final pendingA = Completer<Map>();
        final resolvingA = Completer<void>();
        const current = 'CCCCCCCCCCC';
        await handler.addPlaylistToQueue(
          [song(current)],
          replace: true,
          startIndex: 0,
        );
        final request = consumeInitialSharedTextIntent(
          readInitialText: () async => 'https://youtu.be/$a',
          stillCurrent: () => true,
          consume: (value) => consumeYoutubeSharedTextIntent(
            value,
            audioHandler: handler,
            stillCurrent: () => true,
            resolveSong: (_) {
              resolvingA.complete();
              return pendingA.future;
            },
            onError: (error, stack) => fail('$error'),
          ),
          onError: (error, stack) => fail('$error'),
        );
        try {
          await resolvingA.future;
          expect(
            player.playing,
            isTrue,
            reason: 'Metadata must not interrupt C',
          );
          expect(player.loadedIds, [current]);
          if (stop) {
            await handler.stop();
          } else {
            await handler.addPlaylistToQueue(
              [song(b)],
              replace: true,
              startIndex: 0,
            );
          }
          pendingA.complete(song(a));
          await request;
          expect(player.loadedIds, stop ? [current] : [current, b]);
          expect(player.playedIds, stop ? [current] : [current, b]);
          expect(player.playing, !stop);
        } finally {
          if (!pendingA.isCompleted) pendingA.complete(song(a));
          await request;
          await handler.stop();
          await player.dispose();
        }
      },
    );
  }

  for (final phase in ['metadata', 'source', 'native']) {
    for (final action in ['warm', 'queue', 'stop', 'pause', 'dispose']) {
      for (final lateError in [false, true]) {
        test(
          '$phase / $action / late ${lateError ? 'error' : 'success'} preserves user intent',
          () async {
            final player = _OwnedPlayer()..gateNativeA = phase == 'native';
            final handler = _SourceGateHandler(player)
              ..gateA = phase == 'source';
            final metadata = Completer<Map>();
            final metadataStarted = Completer<void>();
            final errors = <Object>[];
            var mounted = true;
            var generation = 0;
            const current = 'CCCCCCCCCCC';
            const healthy = 'DDDDDDDDDDD';
            await handler.addPlaylistToQueue(
              [song(current)],
              replace: true,
              startIndex: 0,
            );
            final request = consumeInitialSharedTextIntent(
              readInitialText: () async => 'https://youtu.be/$a',
              stillCurrent: () => mounted && generation == 0,
              consume: (value) => consumeYoutubeSharedTextIntent(
                value,
                audioHandler: handler,
                stillCurrent: () => mounted && generation == 0,
                resolveSong: (_) {
                  metadataStarted.complete();
                  return phase == 'metadata'
                      ? metadata.future
                      : Future.value(song(a));
                },
                onError: (error, stack) => errors.add(error),
              ),
              onError: (error, stack) => errors.add(error),
            );
            void release() {
              final error = StateError('synthetic stale $phase failure');
              if (phase == 'metadata' && !metadata.isCompleted) {
                lateError
                    ? metadata.completeError(error)
                    : metadata.complete(song(a));
              } else if (phase == 'source' &&
                  !handler.releaseSource.isCompleted) {
                lateError
                    ? handler.releaseSource.completeError(error)
                    : handler.releaseSource.complete();
              } else if (phase == 'native' &&
                  !player.releaseNative.isCompleted) {
                lateError
                    ? player.releaseNative.completeError(error)
                    : player.releaseNative.complete();
              }
            }

            try {
              if (phase == 'metadata') {
                await metadataStarted.future;
                expect(
                  player.playing,
                  isTrue,
                  reason: 'Metadata leaves current audio alone',
                );
              } else if (phase == 'source') {
                await handler.sourceStarted.future;
              } else {
                await player.nativeStarted.future;
              }
              switch (action) {
                case 'warm':
                  generation++;
                  await consumeYoutubeSharedTextIntent(
                    'https://youtu.be/$b',
                    audioHandler: handler,
                    stillCurrent: () => mounted && generation == 1,
                    resolveSong: (_) async => song(b),
                    onError: (error, stack) => errors.add(error),
                  );
                case 'queue':
                  await handler.addPlaylistToQueue(
                    [song(b)],
                    replace: true,
                    startIndex: 0,
                  );
                case 'stop':
                  await handler.stop();
                case 'pause':
                  await handler.pause();
                case 'dispose':
                  mounted = false;
              }
              final playedAtControl = List<String>.from(player.playedIds);
              release();
              await request;
              expect(errors, isEmpty, reason: 'Stale failure must not escape');
              expect(
                player.playedIds,
                playedAtControl,
                reason: 'No stale autoplay/replay',
              );
              expect(
                player.playing,
                action == 'warm' ||
                    action == 'queue' ||
                    (action == 'dispose' && phase == 'metadata'),
              );
              expect(handler.playbackState.value.errorMessage, isNull);
              if (action == 'warm' || action == 'queue')
                expectSelection(handler, b);
              await handler.addPlaylistToQueue(
                [song(healthy)],
                replace: true,
                startIndex: 0,
              );
              final loads = List<String>.from(player.loadedIds);
              await handler.pause();
              expect(player.playing, isFalse);
              await handler.play();
              expect(
                player.playing,
                isTrue,
                reason: 'Later healthy explicit Play must work',
              );
              expect(player.playedIds.last, healthy);
              expect(
                player.loadedIds,
                loads,
                reason: 'Healthy resume does not reload',
              );
            } finally {
              release();
              await request;
              await handler.stop();
              await player.dispose();
            }
          },
        );
      }
    }
  }

  for (final enableShuffle in [false, true]) {
    for (final lateError in [false, true]) {
      test(
        'metadata A yields to gated queue B shuffle=$enableShuffle error=$lateError',
        () async {
          final player = _OwnedPlayer();
          final handler = _SourceGateHandler(player);
          const current = 'CCCCCCCCCCC';
          await handler.addPlaylistToQueue(
            [song(current)],
            replace: true,
            startIndex: 0,
          );
          final metadata = Completer<Map>();
          final resolving = Completer<void>();
          final errors = <Object>[];
          final shared = consumeYoutubeSharedTextIntent(
            'https://youtu.be/$a',
            audioHandler: handler,
            stillCurrent: () => true,
            resolveSong: (_) {
              resolving.complete();
              return metadata.future;
            },
            onError: (error, stack) => errors.add(error),
          );
          await resolving.future;
          player.gateShuffle = true;
          player.gateShuffleValue = enableShuffle;
          final queued = handler.addPlaylistToQueue(
            [song(b)],
            replace: true,
            startIndex: 0,
            shuffle: enableShuffle,
          );
          try {
            await player.shuffleStarted.future;
            metadata.complete(song(a));
            await shared;
            expect(player.playedIds, [
              current,
            ], reason: 'Queue request owns its native wait');
            lateError
                ? player.releaseShuffle.completeError(
                    StateError('synthetic stale shuffle'),
                  )
                : player.releaseShuffle.complete();
            await queued;
            expect(errors, isEmpty);
            expect(
              player.playedIds,
              lateError && !enableShuffle ? [current] : [current, b],
            );
            expectSelection(handler, lateError && !enableShuffle ? current : b);
          } finally {
            if (!metadata.isCompleted) metadata.complete(song(a));
            if (!player.releaseShuffle.isCompleted)
              player.releaseShuffle.complete();
            await shared;
            await queued;
            await handler.stop();
            await player.dispose();
          }
        },
      );

      test(
        'gated queue A yields to pending shared B shuffle=$enableShuffle error=$lateError',
        () async {
          final player = _OwnedPlayer();
          final handler = _SourceGateHandler(player);
          const current = 'CCCCCCCCCCC';
          await handler.addPlaylistToQueue(
            [song(current)],
            replace: true,
            startIndex: 0,
          );
          player.gateShuffle = true;
          player.gateShuffleValue = enableShuffle;
          final queued = handler.addPlaylistToQueue(
            [song(a)],
            replace: true,
            startIndex: 0,
            shuffle: enableShuffle,
          );
          await player.shuffleStarted.future;
          final metadata = Completer<Map>();
          final resolving = Completer<void>();
          final errors = <Object>[];
          final shared = consumeYoutubeSharedTextIntent(
            'https://youtu.be/$b',
            audioHandler: handler,
            stillCurrent: () => true,
            resolveSong: (_) {
              resolving.complete();
              return metadata.future;
            },
            onError: (error, stack) => errors.add(error),
          );
          try {
            await resolving.future;
            lateError
                ? player.releaseShuffle.completeError(
                    StateError('synthetic old queue'),
                  )
                : player.releaseShuffle.complete();
            await queued;
            expect(
              player.playedIds,
              [current],
              reason:
                  'Older queue cannot play during newer metadata resolution',
            );
            expectSelection(handler, current);
            metadata.complete(song(b));
            await shared;
            expect(errors, isEmpty);
            expect(player.playedIds, [current, b]);
            expectSelection(handler, b);
          } finally {
            if (!metadata.isCompleted) metadata.complete(song(b));
            if (!player.releaseShuffle.isCompleted)
              player.releaseShuffle.complete();
            await queued;
            await shared;
            await handler.stop();
            await player.dispose();
          }
        },
      );

      for (final pause in [false, true]) {
        test(
          'gated queue yields to ${pause ? 'Pause' : 'Stop'} shuffle=$enableShuffle error=$lateError',
          () async {
            final player = _OwnedPlayer();
            final handler = _SourceGateHandler(player);
            const current = 'CCCCCCCCCCC';
            const healthy = 'DDDDDDDDDDD';
            await handler.addPlaylistToQueue(
              [song(current)],
              replace: true,
              startIndex: 0,
            );
            player.gateShuffle = true;
            player.gateShuffleValue = enableShuffle;
            final queued = handler.addPlaylistToQueue(
              [song(a)],
              replace: true,
              startIndex: 0,
              shuffle: enableShuffle,
            );
            try {
              await player.shuffleStarted.future;
              pause ? await handler.pause() : await handler.stop();
              lateError
                  ? player.releaseShuffle.completeError(
                      StateError('synthetic cancelled queue'),
                    )
                  : player.releaseShuffle.complete();
              await queued;
              expect(player.playedIds, [current]);
              expect(player.playing, isFalse);
              expectSelection(handler, current);
              await handler.play();
              expect(player.playing, isTrue);
              expectSelection(handler, current);
              await handler.addPlaylistToQueue(
                [song(healthy)],
                replace: true,
                startIndex: 0,
              );
              await handler.pause();
              await handler.play();
              expect(player.playing, isTrue);
              expect(player.playedIds.last, healthy);
            } finally {
              if (!player.releaseShuffle.isCompleted)
                player.releaseShuffle.complete();
              await queued;
              await handler.stop();
              await player.dispose();
            }
          },
        );
      }
    }
  }

  for (final action in ['queue', 'stop', 'pause', 'warm', 'dispose']) {
    for (final lateError in [false, true]) {
      test(
        'initial text read yields to $action with late ${lateError ? 'error' : 'success'}',
        () async {
          final player = _OwnedPlayer();
          final handler = _SourceGateHandler(player);
          const current = 'CCCCCCCCCCC';
          await handler.addPlaylistToQueue(
            [song(current)],
            replace: true,
            startIndex: 0,
          );
          var mounted = true;
          var generation = 0;
          var metadataCalls = 0;
          final errors = <Object>[];
          final initial = Completer<String?>();
          final request = consumeInitialSharedTextIntent(
            audioHandler: handler,
            readInitialText: () => initial.future,
            stillCurrent: () => mounted && generation == 0,
            consume: (value) => consumeYoutubeSharedTextIntent(
              value,
              audioHandler: handler,
              stillCurrent: () => mounted && generation == 0,
              resolveSong: (_) async {
                metadataCalls++;
                return song(a);
              },
              onError: (error, stack) => errors.add(error),
            ),
            onError: (error, stack) => errors.add(error),
          );
          Future<void>? pendingQueue;
          try {
            switch (action) {
              case 'queue':
                player.gateShuffle = true;
                pendingQueue = handler.addPlaylistToQueue(
                  [song(b)],
                  replace: true,
                  startIndex: 0,
                );
                await player.shuffleStarted.future;
              case 'stop':
                await handler.stop();
              case 'pause':
                await handler.pause();
              case 'warm':
                generation++;
                await consumeYoutubeSharedTextIntent(
                  'https://youtu.be/$b',
                  audioHandler: handler,
                  stillCurrent: () => mounted && generation == 1,
                  resolveSong: (_) async => song(b),
                  onError: (error, stack) => errors.add(error),
                );
              case 'dispose':
                mounted = false;
            }
            final played = List<String>.from(player.playedIds);
            lateError
                ? initial.completeError(
                    StateError('synthetic stale initial read'),
                  )
                : initial.complete('https://youtu.be/$a');
            await request;
            expect(metadataCalls, 0);
            expect(errors, isEmpty);
            expect(player.playedIds, played);
            if (pendingQueue != null) {
              player.releaseShuffle.complete();
              await pendingQueue;
              expect(player.playedIds, [current, b]);
            }
            expect(player.playing, action != 'stop' && action != 'pause');
          } finally {
            if (!initial.isCompleted) initial.complete('https://youtu.be/$a');
            if (pendingQueue != null && !player.releaseShuffle.isCompleted)
              player.releaseShuffle.complete();
            await request;
            await pendingQueue;
            await handler.stop();
            await player.dispose();
          }
        },
      );
    }
  }

  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    await Hive.close();
  });
}

class _SourceGateHandler extends MusifyAudioHandler {
  _SourceGateHandler(AudioPlayer player) : super(player: player);
  bool gateA = false;
  final sourceStarted = Completer<void>();
  final releaseSource = Completer<void>();
  @override
  Future<AudioSource?> buildAudioSource(
    Map song,
    String url,
    bool offline,
  ) async {
    if (gateA && song['ytid'] == 'AAAAAAAAAAA') {
      sourceStarted.complete();
      await releaseSource.future;
    }
    return super.buildAudioSource(song, url, offline);
  }
}

class _OwnedPlayer extends AudioPlayer {
  _OwnedPlayer() : super(handleAudioSessionActivation: false) {
    _testPlayers.add(this);
  }
  final errors = StreamController<PlayerException>.broadcast();
  final loadedIds = <String>[];
  final playedIds = <String>[];
  final nativeStarted = Completer<void>();
  final releaseNative = Completer<void>();
  bool gateNativeA = false;
  bool gateShuffle = false;
  bool gateShuffleValue = false;
  final shuffleStarted = Completer<void>();
  final releaseShuffle = Completer<void>();
  bool active = false;
  AudioSource? source;
  Completer<void>? pendingPlay;
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  bool get playing => active;
  @override
  AudioSource? get audioSource => source;
  @override
  Duration? get duration => const Duration(seconds: 30);
  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    if (gateShuffle &&
        enabled == gateShuffleValue &&
        !shuffleStarted.isCompleted) {
      shuffleStarted.complete();
      await releaseShuffle.future;
    }
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource value, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = value;
    final id = (value as IndexedAudioSource).tag.title as String;
    loadedIds.add(id);
    if (gateNativeA && id == 'AAAAAAAAAAA') {
      nativeStarted.complete();
      await releaseNative.future;
    }
    return duration;
  }

  @override
  Future<void> play() {
    active = true;
    playedIds.add((source as IndexedAudioSource).tag.title as String);
    pendingPlay = Completer<void>();
    return pendingPlay!.future;
  }

  @override
  Future<void> pause() async => stop();
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
