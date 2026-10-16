import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('playback-retry-test-');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('user');
    await Hive.openBox('userNoBackup');
    await Hive.openBox('cache');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // These ytids are deliberately not valid YouTube video ids, so every
  // playback attempt fails immediately and locally (a parse error, not a
  // network round trip or a platform-channel call) — a stand-in for "this
  // queue item is unplayable" (geo-blocked, deleted upload, transient
  // network hiccup, etc). Every song in the queue fails identically, so the
  // only thing that can distinguish "advanced to a new song" from "retried
  // the same one" is how many *distinct* songs the handler ever attempted.
  Map<String, dynamic> song(String ytid, String title) {
    return {'ytid': ytid, 'title': title, 'highResImage': ''};
  }

  test(
    'runtime error pauses once and advances past its actual failed item',
    () async {
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      offlineMode.value = true;
      final attempts = <String>[];
      final handler = _ControlledHandler((item) async {
        attempts.add(item['title'] as String);
        return true;
      });
      try {
        await handler.addPlaylistToQueue(
          [song('first', 'First'), song('next', 'Next')],
          replace: true,
          startIndex: 0,
        );
        await Future.wait([
          handler.handleRuntimePlaybackError(
            PlayerException(403, 'fixture denied', 0),
          ),
          handler.handleRuntimePlaybackError(
            PlayerException(403, 'fixture denied', 0),
          ),
        ]);
        expect(handler.pauseCalls, 1);
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(attempts, ['First', 'Next']);
        expect(handler.currentSong!['title'], 'Next');
      } finally {
        await handler.audioPlayer.dispose();
        offlineMode.value = false;
      }
    },
  );

  test(
    'a new user selection supersedes the pending runtime-error retry',
    () async {
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      offlineMode.value = true;
      final attempts = <String>[];
      final handler = _ControlledHandler((item) async {
        attempts.add(item['title'] as String);
        return true;
      });
      try {
        await handler.addPlaylistToQueue(
          [
            song('first', 'First'),
            song('next', 'Next'),
            song('chosen', 'Chosen'),
          ],
          replace: true,
          startIndex: 0,
        );
        await handler.handleRuntimePlaybackError(
          PlayerException(403, 'fixture denied', 0),
        );
        await handler.skipToQueueItem(2);
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(attempts, ['First', 'Chosen']);
        expect(handler.currentSong!['title'], 'Chosen');
      } finally {
        await handler.audioPlayer.dispose();
        offlineMode.value = false;
      }
    },
  );

  test('explicit stop cancels the pending runtime-error retry', () async {
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
    offlineMode.value = true;
    final attempts = <String>[];
    final handler = _ControlledHandler((item) async {
      attempts.add(item['title'] as String);
      return true;
    });
    try {
      await handler.addPlaylistToQueue(
        [song('first', 'First'), song('next', 'Next')],
        replace: true,
        startIndex: 0,
      );
      await handler.handleRuntimePlaybackError(
        PlayerException(403, 'fixture denied', 0),
      );
      await handler.stop();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(attempts, ['First']);
    } finally {
      await handler.audioPlayer.dispose();
      offlineMode.value = false;
    }
  });

  test('natural repeat-off completion pauses at the final item', () async {
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.none;
    offlineMode.value = true;
    final attempts = <String>[];
    final handler = _ControlledHandler((item) async {
      attempts.add(item['title'] as String);
      return true;
    });
    try {
      await handler.addPlaylistToQueue(
        [song('first', 'First'), song('final', 'Final')],
        replace: true,
        startIndex: 0,
      );
      await handler.handleSongCompletion();
      expect(attempts, ['First', 'Final']);
      expect(handler.pauseCalls, 0);
      await handler.handleSongCompletion();
      expect(attempts, ['First', 'Final']);
      expect(handler.pauseCalls, 1);
      expect(handler.currentSong!['title'], 'Final');
    } finally {
      await handler.audioPlayer.dispose();
      offlineMode.value = false;
    }
  });

  test('repeat-all completion wraps without pausing', () async {
    playNextSongAutomatically.value = false;
    repeatNotifier.value = AudioServiceRepeatMode.all;
    offlineMode.value = true;
    final attempts = <String>[];
    final handler = _ControlledHandler((item) async {
      attempts.add(item['title'] as String);
      return true;
    });
    try {
      await handler.addPlaylistToQueue(
        [song('first', 'First'), song('final', 'Final')],
        replace: true,
        startIndex: 1,
      );
      await handler.handleSongCompletion();
      expect(attempts, ['Final', 'First']);
      expect(handler.pauseCalls, 0);
      expect(handler.currentSong!['title'], 'First');
    } finally {
      await handler.audioPlayer.dispose();
      offlineMode.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
    }
  });

  test(
    'a healthy first track followed by a failed final track is not retried',
    () async {
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
      offlineMode.value = true;
      final attempts = <String>[];
      final handler = _ControlledHandler((song) async {
        attempts.add(song['title'] as String);
        return song['title'] == 'Healthy';
      });
      await handler.addPlaylistToQueue(
        [song('healthy', 'Healthy'), song('failed', 'Failed')],
        replace: true,
        startIndex: 0,
      );
      await handler.skipToNext();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(attempts, ['Healthy', 'Failed']);
      expect(handler.currentSong!['title'], 'Healthy');
      await handler.audioPlayer.dispose();
      offlineMode.value = false;
    },
  );

  test(
    'failed middle advances and repeat-all wraps from the failed tail',
    () async {
      playNextSongAutomatically.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.all;
      offlineMode.value = true;
      final attempts = <String>[];
      final handler = _ControlledHandler((song) async {
        attempts.add(song['title'] as String);
        return song['title'] == 'Healthy';
      });
      await handler.addPlaylistToQueue(
        [song('healthy', 'Healthy'), song('failed', 'Failed')],
        replace: true,
        startIndex: 0,
      );
      await handler.skipToNext();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(attempts, ['Healthy', 'Failed', 'Healthy']);
      await handler.audioPlayer.dispose();
      offlineMode.value = false;
      repeatNotifier.value = AudioServiceRepeatMode.none;
    },
  );

  test('repeated playback failures advance through the queue instead of '
      'retrying the same item forever', () async {
    final handler = MusifyAudioHandler();

    final attemptedTitles = <String>{};
    final subscription = handler.mediaItem.listen((item) {
      if (item != null) attemptedTitles.add(item.title);
    });

    final songs = [
      song('retry-test-song-0', 'Song 0'),
      song('retry-test-song-1', 'Song 1'),
      song('retry-test-song-2', 'Song 2'),
      song('retry-test-song-3', 'Song 3'),
    ];

    await handler.addPlaylistToQueue(songs, replace: true, startIndex: 0);

    // The handler retries on a 2-second delay, up to 3 consecutive
    // failures, before giving up. Give the whole retry chain time to run
    // to completion in real time.
    await Future<void>.delayed(const Duration(seconds: 7));

    await subscription.cancel();

    // Song 0 (the initial attempt) and Song 1 (the first retry) are
    // always attempted. The bug under test is whether the handler ever
    // moves past Song 1 to a third, distinct song — proving it advanced
    // through the queue on repeated failure instead of retrying Song 1
    // forever.
    expect(attemptedTitles, containsAll(<String>['Song 0', 'Song 1']));
    expect(
      attemptedTitles.length,
      greaterThanOrEqualTo(3),
      reason:
          'playback must advance to a new queue item on repeated '
          'failure, not retry the same failing item forever '
          '(attempted only: $attemptedTitles)',
    );
  });
}

class _ControlledHandler extends MusifyAudioHandler {
  _ControlledHandler(Future<bool> Function(Map) playback)
    : this._(playback, _PauseSpyPlayer());
  _ControlledHandler._(this.playback, this.pausePlayer)
    : super(player: pausePlayer);
  final Future<bool> Function(Map) playback;
  final _PauseSpyPlayer pausePlayer;
  int get pauseCalls => pausePlayer.pauseCalls;

  @override
  Future<bool> playSong(Map song, {String? mediaId, int? transitionId}) =>
      playback(song);
}

// Observe the real pause boundary shared by user and internal pauses. Spying
// on the public user action would miss deliberate internal transition retention.
class _PauseSpyPlayer extends AudioPlayer {
  _PauseSpyPlayer() : super(handleAudioSessionActivation: false);
  int pauseCalls = 0;
  @override
  Future<void> pause() async {
    pauseCalls++;
  }
}
