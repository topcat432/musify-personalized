// Owned data only; exercise the production handler without restoring a fake queue.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/io_service.dart';
import 'package:musify/services/settings_manager.dart';

import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal(
    namespace: 'acceptance_queue_restart_v1',
    bootstrapQueue: false,
  );
  final user = Hive.box('user');
  final stage = user.get('ownedQueueRestartStage', defaultValue: 0) as int;
  final observations = <Map<String, Object?>>[];
  void require(bool condition, String label) {
    if (!condition) throw StateError(label);
    observations.add({'check': label, 'pass': true});
  }

  Future<void> waitPlaying() async {
    final limit = DateTime.now().add(const Duration(seconds: 10));
    while (!audioHandler.audioPlayer.playing &&
        DateTime.now().isBefore(limit)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    require(audioHandler.audioPlayer.playing, 'owned native playback starts');
  }

  require(
    audioHandler.queue.value.isEmpty,
    'cold startup has no restored queue',
  );
  require(!audioHandler.audioPlayer.playing, 'cold startup does not autoplay');
  if (stage == 0) {
    final records = (Hive.box('userNoBackup').get('offlineSongs') as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final loading = audioHandler.addPlaylistToQueue(
      records,
      replace: true,
      startIndex: 0,
    );
    await waitPlaying();
    await audioHandler.pause();
    await loading;
    final selected = audioHandler.currentSong!['ytid'];
    final natural = audioHandler.queue.value
        .map((item) => item.extras!['ytid'])
        .toList();
    for (var cycle = 0; cycle < 2; cycle++) {
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
      require(
        audioHandler.currentSong!['ytid'] == selected,
        'shuffle/repeat-on retains selected recording $cycle',
      );
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
      await audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
      require(
        jsonEncode(
              audioHandler.queue.value
                  .map((item) => item.extras!['ytid'])
                  .toList(),
            ) ==
            jsonEncode(natural),
        'shuffle/repeat-off restores exact source order $cycle',
      );
      await audioHandler.stop();
      await audioHandler.stop();
      require(
        !audioHandler.audioPlayer.playing &&
            audioHandler.audioPlayer.processingState == ProcessingState.idle,
        'repeated stop remains idle $cycle',
      );
      require(
        audioHandler.currentSong!['ytid'] == selected &&
            jsonEncode(
                  audioHandler.queue.value
                      .map((item) => item.extras!['ytid'])
                      .toList(),
                ) ==
                jsonEncode(natural),
        'stop preserves session queue recording/order $cycle',
      );
      unawaited(audioHandler.play());
      await waitPlaying();
      require(
        audioHandler.currentSong!['ytid'] == selected,
        'explicit replay after stop retains recording $cycle',
      );
      await audioHandler.stop();
    }
    await audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
  } else {
    require(
      shuffleNotifier.value,
      'shuffle preference survives native process restart',
    );
    require(
      repeatNotifier.value == AudioServiceRepeatMode.one,
      'repeat preference survives native process restart',
    );
    require(
      audioHandler.mediaItem.valueOrNull == null,
      'cold startup does not invent selected recording',
    );
    await audioHandler.stop();
    await audioHandler.stop();
    require(
      !audioHandler.audioPlayer.playing && audioHandler.queue.value.isEmpty,
      'repeated stop on cold empty queue stays stopped',
    );
    unawaited(audioHandler.play());
    await waitPlaying();
    require(
      audioHandler.currentSong!['ytid'] == 'owned-mini-70' &&
          audioHandler.queue.value.length == 1,
      'explicit cold replay resumes exact latest recording, not former queue',
    );
    await audioHandler.stop();
    await audioHandler.stop();
    require(
      !audioHandler.audioPlayer.playing &&
          audioHandler.audioPlayer.processingState == ProcessingState.idle,
      'cold replay repeated stop stays idle',
    );
    await audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
  }
  await user.put('ownedQueueRestartStage', stage + 1);
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.box(name).flush();
  }
  await File(
    '$applicationDirPath/queue-restart-stage-$stage.json',
  ).writeAsString(
    jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'stage': stage,
      'observations': observations,
      'queueDurableRestorationImplemented': false,
      'ownedMediaOnly': true,
      'physicalAudioVerified': false,
    }),
    flush: true,
  );
}
