import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';

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
  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

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
    loadedIds.add((audioSource as UriAudioSource).tag.title as String);
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
