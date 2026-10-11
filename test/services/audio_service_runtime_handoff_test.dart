import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/online_audio_source.dart';

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
        (await miniPlayerError.timeout(const Duration(seconds: 1))).errorMessage,
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

class _ReplayPlayer extends _PendingPlayer {
  final seeks = <Duration>[];
  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position!);
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
