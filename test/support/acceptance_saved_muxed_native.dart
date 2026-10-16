// Owned namespace only; the authorized saved recording/input stay outside Git.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/io_service.dart';

import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal(
    namespace: 'acceptance_saved_muxed_v1',
    bootstrapQueue: false,
  );
  final root = applicationDirPath;
  Future<void> proof(String stage, Map<String, Object?> details) async {
    await File('$root/proof-$stage.json').writeAsString(
      jsonEncode({
        'sourceSha': const String.fromEnvironment('GIT_SHA'),
        'stage': stage,
        'physicalOutputVerified': false,
        'providerRequests': 0,
        ...details,
      }),
      flush: true,
    );
  }

  void require(bool value, String label) {
    if (!value) throw StateError(label);
  }

  Future<void> waitUntil(bool Function() ready, Duration limit) async {
    final end = DateTime.now().add(limit);
    while (!ready()) {
      if (DateTime.now().isAfter(end)) throw StateError('Stage deadline');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  unawaited(() async {
    try {
      final input = Map<String, dynamic>.from(
        jsonDecode(await File('$root/authorized-input.json').readAsString())
            as Map,
      );
      final id = input['videoId'] as String;
      final duration = input['durationSeconds'] as int;
      final expectedBytes = input['bytes'] as int;
      final expectedSha = input['sha256'] as String;
      require(duration > 20 && duration <= 600, 'Bounded duration');
      require(
        expectedBytes > 0 && expectedBytes <= 96 * 1024 * 1024,
        'Bounded saved source',
      );
      final saved = File('$root/authorized-saved.mp4');
      require(await saved.length() == expectedBytes, 'Saved length matches');
      require(
        (await sha256.bind(saved.openRead()).first).toString() == expectedSha,
        'Saved checksum matches',
      );
      final user = Hive.box('user');
      final offline = Hive.box('userNoBackup');
      final next = Map<String, dynamic>.from(
        (offline.get('offlineSongs') as List).cast<Map>().firstWhere(
          (song) => song['ytid'] == 'owned-mini-8',
        ),
      );
      final selected = <String, dynamic>{
        'ytid': id,
        'title': 'Authorized saved recording',
        'artist': 'Owned acceptance',
        'duration': duration,
        'audioPath': saved.path,
        'artworkPath': next['artworkPath'],
        'image': next['image'],
        'sourceType': 'youtube',
      };
      final stage = user.get('savedMuxedStage', defaultValue: 0) as int;
      require(audioHandler.queue.value.isEmpty, 'Cold queue empty');
      require(
        !audioHandler.audioPlayer.playing,
        'Cold startup does not autoplay',
      );
      if (stage == 1) {
        final persisted = (offline.get('offlineSongs') as List).cast<Map>();
        require(
          persisted.length == 2 &&
              persisted.first['ytid'] == id &&
              persisted.first['audioPath'] == saved.path &&
              persisted.last['ytid'] == next['ytid'],
          'Saved identity/order survive',
        );
        require(
          (user.get('likedSongs') as List).first['ytid'] == id,
          'Selected library membership survives',
        );
        await proof('restart', {
          'checksum': expectedSha,
          'savedPreserved': true,
        });
        return;
      }
      await offline.put('offlineSongs', [selected, next]);
      await user.put('likedSongs', [selected]);
      await audioHandler.audioPlayer.setVolume(0);
      unawaited(
        audioHandler.addPlaylistToQueue(
          [selected, next],
          replace: true,
          startIndex: 0,
        ),
      );
      await waitUntil(
        () => audioHandler.audioPlayer.playing,
        const Duration(seconds: 20),
      );
      require(
        (audioHandler.audioPlayer.duration!.inSeconds - duration).abs() <= 1,
        'Native decoded duration matches',
      );
      await audioHandler.pause();
      for (final position in [duration ~/ 2, duration - 5]) {
        await audioHandler.seek(Duration(seconds: position));
        await audioHandler.play();
        await waitUntil(
          () => audioHandler.audioPlayer.position.inSeconds >= position + 1,
          const Duration(seconds: 10),
        );
        require(
          audioHandler.currentSong!['ytid'] == id,
          'Seek retains recording',
        );
        await audioHandler.pause();
      }
      await audioHandler.seek(Duration.zero);
      await audioHandler.play();
      await proof('prepared', {
        'durationSeconds': duration,
        'checksum': expectedSha,
        'middleAndTailSeek': true,
      });
      await waitUntil(
        () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused,
        const Duration(seconds: 30),
      );
      final before = audioHandler.audioPlayer.position;
      await Future<void>.delayed(const Duration(seconds: 3));
      require(
        audioHandler.audioPlayer.position - before >=
            const Duration(seconds: 2),
        'Background advances',
      );
      await proof('background', {'advanced': true});
      var maximumPosition = audioHandler.audioPlayer.position.inMilliseconds;
      await waitUntil(() {
        if (audioHandler.currentSong?['ytid'] == id) {
          final value = audioHandler.audioPlayer.position.inMilliseconds;
          if (value > maximumPosition) maximumPosition = value;
        }
        return audioHandler.currentSong?['ytid'] == next['ytid'];
      }, Duration(seconds: duration + 30));
      require(
        maximumPosition >= duration * 1000 - 1500,
        'Full saved recording reaches tail',
      );
      await waitUntil(
        () =>
            audioHandler.audioPlayer.processingState ==
            ProcessingState.completed,
        const Duration(seconds: 20),
      );
      require(
        audioHandler.currentSong!['ytid'] == next['ytid'],
        'Next recording completes',
      );
      await audioHandler.stop();
      await user.put('savedMuxedStage', 1);
      for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
        await Hive.box(name).flush();
      }
      await proof('complete', {
        'fullSavedTrackAndNext': true,
        'maximumPositionMs': maximumPosition,
        'checksum': expectedSha,
      });
    } catch (error) {
      await audioHandler.stop();
      await proof('failed', {'error': error.toString()});
    }
  }());
}
