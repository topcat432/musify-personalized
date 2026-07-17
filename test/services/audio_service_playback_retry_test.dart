import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/services/audio_service.dart';

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
