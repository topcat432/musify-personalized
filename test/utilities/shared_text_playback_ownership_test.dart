import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/sharing_intent.dart';

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
  _OwnedPlayer() : super(handleAudioSessionActivation: false);
  final errors = StreamController<PlayerException>.broadcast();
  final loadedIds = <String>[];
  final playedIds = <String>[];
  final nativeStarted = Completer<void>();
  final releaseNative = Completer<void>();
  bool gateNativeA = false;
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
