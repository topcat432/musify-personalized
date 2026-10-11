import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/audio_service.dart';
import 'package:musify/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('shuffle-state-test-');
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

  // These ytids are deliberately not valid YouTube video ids. Resolving a
  // stream URL for them fails immediately and locally (a parse error, not a
  // network round trip), so `playSong` fails deterministically without ever
  // touching the platform's audio player — which has no real implementation
  // in a `flutter test` unit-test environment. The shuffle/queue bookkeeping
  // this test checks is all updated synchronously before that playback
  // attempt resolves, so it's unaffected by the playback outcome.
  Map<String, dynamic> song(String ytid, String title) {
    return {'ytid': ytid, 'title': title};
  }

  test('shuffle is ready before an ongoing playback future completes '
      'state consistent and does not lose the queue', () async {
    final playback = Completer<bool>();
    final started = Completer<void>();
    final handler = _ControlledHandler((song) {
      if (!started.isCompleted) started.complete();
      return playback.future;
    });

    final songs = [
      song('shuffle-state-song-a', 'A'),
      song('shuffle-state-song-b', 'B'),
      song('shuffle-state-song-c', 'C'),
      song('shuffle-state-song-d', 'D'),
    ];

    // Mirrors the fixed Shuffle button flow: queue the natural order via
    // replace, then explicitly enable shuffle through the real toggle
    // machinery instead of pre-shuffling client-side.
    final queueOperation = handler.addPlaylistToQueue(
      songs,
      replace: true,
      startIndex: 0,
      shuffle: true,
    );
    await started.future;
    // The player future is deliberately still pending while music plays.
    expect(playback.isCompleted, isFalse);

    expect(
      shuffleNotifier.value,
      isTrue,
      reason: 'the shuffle toggle must read enabled after a shuffle play',
    );
    expect(
      Hive.box('settings').get('shuffleEnabled'),
      isTrue,
      reason: 'the persisted shuffle preference must match the real state',
    );

    final currentAfterShuffle = handler.currentSong;
    expect(currentAfterShuffle, isNotNull);
    expect(
      currentAfterShuffle!['ytid'],
      'shuffle-state-song-a',
      reason: 'shuffling must not change which song is currently playing',
    );

    expect(
      handler.queue.valueOrNull?.length,
      songs.length,
      reason: 'no songs may be dropped when shuffle is enabled',
    );
    playback.complete(true);
    await queueOperation;
    await handler.setShuffleMode(AudioServiceShuffleMode.none);
    expect(handler.queue.value.map((item) => item.title), ['A', 'B', 'C', 'D']);
    await handler.audioPlayer.dispose();
  });

  test(
    'a bare replace with no explicit shuffle leaves shuffle state off',
    () async {
      final handler = MusifyAudioHandler();
      addTearDown(handler.audioPlayer.dispose);

      final songs = [
        song('shuffle-state-song-e', 'E'),
        song('shuffle-state-song-f', 'F'),
      ];

      await handler.addPlaylistToQueue(songs, replace: true, startIndex: 0);

      expect(shuffleNotifier.value, isFalse);
      expect(Hive.box('settings').get('shuffleEnabled'), isFalse);
    },
  );
}

class _ControlledHandler extends MusifyAudioHandler {
  _ControlledHandler(this.playback);
  final Future<bool> Function(Map) playback;
  @override
  Future<bool> playSong(Map song, {String? mediaId, int? transitionId}) =>
      playback(song);
}
