// Approved-scope native rehearsal; only owned local media and isolated boxes.
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler;
import 'package:musify/services/common_services.dart'
    show songStreamUrlCacheKey;
import 'package:musify/services/io_service.dart';
import 'package:musify/services/settings_manager.dart';

import 'acceptance_mini_shell_native.dart';

Future<void> main() async {
  await runOwnedShellRehearsal();
  final oldMode = offlineMode.value;
  final selected = audioHandler.currentSong!['ytid'];
  final source = audioHandler.audioPlayer.audioSource;
  final queue = audioHandler.queue.value.map((item) => item.id).toList();
  final offline = Hive.box('userNoBackup').get('offlineSongs') as List;
  final ownedPath = (offline.first as Map)['audioPath'] as String;
  final results = <Map<String, Object?>>[];
  await Hive.box('settings').put('offlineMode', true);
  offlineMode.value = true;
  try {
    for (final missingPath in [false, true]) {
      final key = songStreamUrlCacheKey('owned-unsaved-$missingPath');
      final location = Uri.file(ownedPath).toString();
      await Hive.box(
        'cache',
      ).putAll({key: location, '${key}_date': DateTime.now()});
      final played = await audioHandler.playSong({
        'ytid': 'owned-unsaved-$missingPath',
        'title': 'Owned missing saved recording',
        if (missingPath) 'audioPath': '$applicationDirPath/not-present.wav',
      });
      if (played ||
          audioHandler.audioPlayer.playing ||
          !identical(source, audioHandler.audioPlayer.audioSource) ||
          audioHandler.currentSong!['ytid'] != selected ||
          jsonEncode(queue) !=
              jsonEncode(
                audioHandler.queue.value.map((item) => item.id).toList(),
              ) ||
          Hive.box('cache').get(key) != location) {
        throw StateError(
          'Offline-only guard changed source/queue or played unsaved audio',
        );
      }
      results.add({
        'missingPath': missingPath,
        'rejected': true,
        'loadedSourceSelectedRecordingAndQueuePreserved': true,
        'syntheticCachedLocationPreserved': true,
      });
    }
  } finally {
    await Hive.box('settings').put('offlineMode', oldMode);
    offlineMode.value = oldMode;
  }
  for (final name in ['settings', 'user', 'userNoBackup', 'cache']) {
    await Hive.box(name).flush();
  }
  await File(
    '$applicationDirPath/supported-mode-guard-native-proof.json',
  ).writeAsString(
    jsonEncode({
      'sourceSha': const String.fromEnvironment('GIT_SHA'),
      'cases': results,
      'nativeLocalMediaOnly': true,
      'providerMediaRequested': false,
      'originalModeRestored': true,
      'physicalOutputVerified': false,
    }),
    flush: true,
  );
}
